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

### Calculate

Tool name (macro-derived): `calculate`

```swift
/// Evaluates a basic arithmetic expression and returns the result as a Double.
@LLMTool
public struct Calculate: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "A math expression using +, -, *, /. Example: '144 / 12'")
        var expression: String
    }
    public static var isConcurrencySafe: Bool { true }
    public func call(arguments: Arguments) async throws -> ToolOutput { ... }
}
```

Implementation: sanitize `expression` to safe characters, evaluate with `NSExpression`. If empty after sanitizing or evaluation fails, throw `ToolUsingAgentError.toolCallFailed("calculate")`. Return `ToolOutput(content: "\(result.doubleValue)")`.

### ConvertUnit

Tool name (macro-derived): `convert_unit`

```swift
/// Converts a value from one unit to another. Supports length, weight, and temperature.
@LLMTool
public struct ConvertUnit: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "The numeric value to convert.")
        var value: Double
        @LLMToolGuide(description: "Source unit. One of: meters, feet, miles, kilometers, kilograms, pounds, celsius, fahrenheit.")
        var fromUnit: String
        @LLMToolGuide(description: "Target unit. Same options as fromUnit.")
        var toUnit: String
    }
    public static var isConcurrencySafe: Bool { true }
    public func call(arguments: Arguments) async throws -> ToolOutput { ... }
}
```

Implementation: handle temperature as a special case, then use a lookup table of `(factor, dimension)` pairs. Return result formatted to 4 decimal places. Throw `ToolUsingAgentError.toolCallFailed("convert_unit")` on unknown or mismatched units.

### FormatNumber

Tool name (macro-derived): `format_number`

```swift
/// Formats a number with a specified number of decimal places.
@LLMTool
public struct FormatNumber: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "The number to format.")
        var value: Double
        @LLMToolGuide(description: "Number of decimal places. 0–10.", .range(0...10))
        var decimalPlaces: Int
    }
    public static var isConcurrencySafe: Bool { true }
    public func call(arguments: Arguments) async throws -> ToolOutput { ... }
}
```

Implementation: clamp `decimalPlaces` to `0...10`, return `ToolOutput(content: String(format: "%.\(clamped)f", value))`.

---

## Tasks (execute steps)

1. Build `ToolRegistry`, register `Calculate()`, `ConvertUnit()`, `FormatNumber()`. Set `permissionGate` if configured.
2. Call `AgentToolLoop.run(client:config:goal:tools:transcript:maxIterations:hooks:)` with `maxIterations: 10`.
3. Guard non-empty result → throw `ToolUsingAgentError.noResponseContent`.
4. Return result string.

`AgentToolLoop` handles the full dispatch cycle: sending the request with tool definitions, detecting tool calls, dispatching safe tools concurrently (via `isConcurrencySafe`), appending `.toolCall` / `.toolResult` transcript entries in receive order, feeding results back, and enforcing `maxIterations`.

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
