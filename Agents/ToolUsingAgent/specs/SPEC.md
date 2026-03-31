# Agent Spec: ToolUsingAgent

> Reference implementation for tool-using agents. Demonstrates `@LLMTool` macro usage, the full tool dispatch loop, and concurrent-safe tool scheduling.

---

## Goal

Accept a natural-language math or unit-conversion request, dispatch one or more tool calls chosen by the LLM, and return a plain-language answer. This agent is intentionally simple so the tool dispatch pattern is unambiguous and copy-pasteable.

---

## Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `configuration` | `AgentConfiguration` | — | Server URL, model, API key, timeout, retry count, tool result budget |

Follows `Shared-Configuration.md`. No additional stored properties beyond what `AgentConfiguration` provides.

---

## Input

| Parameter | Type | Description |
|-----------|------|-------------|
| `goal` | `String` | A natural-language math or unit-conversion request (e.g., "What is 144 divided by 12?" or "Convert 100 miles to kilometers") |

---

## Tools

Three tools, all `isConcurrencySafe: true` (pure functions, no side effects):

### calculate

```swift
@LLMTool(description: "Evaluates a basic arithmetic expression and returns the result as a Double.")
func calculate(
    @LLMToolArguments("expression", description: "A math expression using +, -, *, /. Example: '144 / 12'")
    expression: String
) async throws -> String
```

Implementation: parse the expression using `NSExpression`. If parsing fails, throw `ToolUsingAgentError.toolCallFailed("calculate")`.

### convertUnit

```swift
@LLMTool(description: "Converts a value from one unit to another. Supports length, weight, and temperature.")
func convertUnit(
    @LLMToolArguments("value", description: "The numeric value to convert.")
    value: Double,
    @LLMToolArguments("fromUnit", description: "Source unit. One of: meters, feet, miles, kilometers, kilograms, pounds, celsius, fahrenheit.")
    fromUnit: String,
    @LLMToolArguments("toUnit", description: "Target unit. Same options as fromUnit.")
    toUnit: String
) async throws -> String
```

Implementation: a simple lookup table of conversion factors. Returns the result formatted to 4 decimal places. Throws `ToolUsingAgentError.toolCallFailed("convertUnit")` if either unit is unrecognized.

### formatNumber

```swift
@LLMTool(description: "Formats a number with a specified number of decimal places.")
func formatNumber(
    @LLMToolArguments("value", description: "The number to format.")
    value: Double,
    @LLMToolArguments("decimalPlaces", description: "Number of decimal places. 0–10.")
    decimalPlaces: Int
) async throws -> String
```

Implementation: `String(format: "%.\(decimalPlaces)f", value)`. Clamps `decimalPlaces` to `0...10`.

---

## Tasks (execute steps)

1. Validate `goal` is non-empty. Set `_status = .error(ToolUsingAgentError.emptyGoal)` and throw if empty.
2. Reset `_agentContext`. Set `_status = .running`. Emit `agentStarted`. Append `.userMessage(goal)`.
3. Build the initial `ResponseRequest` with all three tool definitions registered.
4. Enter the tool dispatch loop (see `Shared-Tool-Concurrency.md`):
   a. Check `Task.isCancelled` — throw `CancellationError` if cancelled.
   b. Call `retryWithBackoff` wrapping `_llmClient.send(request)`.
   c. If the response contains no tool calls: extract `firstOutputText`, guard non-empty, append `.assistantMessage`, set `.completed`, emit `agentCompleted`, return.
   d. If the response contains tool calls: execute via `ToolExecutor`, append `.toolCall` and `.toolResult` entries in receive order, feed results back as the next request.
   e. Guard `iteration <= 10` — throw `toolLoopExceeded` if exceeded.
5. On any error path: set `_status = .error(e)`, emit `agentFailed`, throw.

---

## Errors

```swift
public enum ToolUsingAgentError: Error, Sendable {
    case emptyGoal               // terminal
    case noResponseContent       // terminal
    case toolCallFailed(String)  // terminal — carries tool name
    case unknownTool(String)     // terminal — carries tool name from LLM
    case toolLoopExceeded        // terminal — more than 10 dispatch iterations
}
```

---

## Output

The LLM's final natural-language answer as a `String`. Example: `"144 divided by 12 equals 12."` or `"100 miles is approximately 160.9344 kilometers."`

---

## Transcript Shape

Minimum (no tools called — LLM answered directly):
```
[0] .userMessage("What is 144 / 12?")
[1] .assistantMessage("144 divided by 12 equals 12.")
```

Typical (one tool call):
```
[0] .userMessage("What is 144 / 12?")
[1] .toolCall(name: "calculate", arguments: "{\"expression\":\"144/12\"}")
[2] .toolResult(name: "calculate", result: "12.0", duration: ...)
[3] .assistantMessage("144 divided by 12 equals 12.")
```

With retry annotation:
```
[0] .userMessage(...)
[1] .reasoning("Retrying LLM call (attempt 2 of 3)…")
[2] .toolCall(...)
[3] .toolResult(...)
[4] .assistantMessage(...)
```

---

## Constraints

- Open Responses API only (no Chat Completions).
- No persistence, no background execution, no streaming (tool results are discrete; streaming is covered by `StreamingChatAgent`).
- `isConcurrencySafe: true` for all three tools — they may run in parallel if the LLM requests them together.
- Tool result budget enforced from `AgentConfiguration.toolResultBudgetTokens`.

---

## Success Criteria

1. A math request produces a `.completed` status and the answer is in the transcript as `.assistantMessage`.
2. A unit-conversion request produces at least one `.toolCall` + `.toolResult` pair in the transcript.
3. Passing an empty goal throws `ToolUsingAgentError.emptyGoal` and status is `.error`.
4. Passing an unknown unit to `convertUnit` throws `ToolUsingAgentError.toolCallFailed("convertUnit")` from within the dispatch function.
5. When the LLM issues two tool calls simultaneously, both `.toolCall` entries appear before both `.toolResult` entries, in receive order.

---

## Platforms

iOS 26+, macOS 26+, visionOS 2.4+. Swift 6.2+ strict concurrency.
