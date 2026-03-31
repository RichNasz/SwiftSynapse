<!-- Generated from CodeGenSpecs/Agent-README-Generation.md + Agents/ToolUsingAgent/specs/SPEC.md — Do not edit manually. -->

# ToolUsingAgent

Accept a natural-language math or unit-conversion request, dispatch tool calls chosen by the LLM, and return a plain-language answer.

## Overview

ToolUsingAgent is the reference implementation for tool-using agents in SwiftSynapse. It demonstrates the complete tool dispatch loop: LLM chooses a tool, agent decodes arguments and calls it, results are fed back to the LLM, and the cycle repeats until the LLM produces a final text response. Three pure-function tools are provided: `calculate`, `convertUnit`, and `formatNumber`.

**Platforms:** iOS 26+, macOS 26+, visionOS 2.4+

## Quick Start

**CLI:**

```bash
swift run tool-using-agent "What is 144 divided by 12?" \
    --server-url http://127.0.0.1:1234/v1/responses \
    --model llama3
```

```bash
swift run tool-using-agent "Convert 100 miles to kilometers" \
    --server-url http://127.0.0.1:1234/v1/responses \
    --model gpt-4o \
    --api-key sk-...
```

**Programmatic:**

```swift
import ToolUsingAgentAgent

let agent = try ToolUsingAgent(
    serverURL: "http://127.0.0.1:1234/v1/responses",
    modelName: "llama3"
)
let answer = try await agent.execute(goal: "What is 25 times 4?")
print(answer) // "25 times 4 equals 100."
```

## Tools

| Tool | Description |
|------|-------------|
| `calculate` | Evaluates an arithmetic expression via `NSExpression` |
| `convertUnit` | Converts between meters, feet, miles, km, kg, lb, celsius, fahrenheit |
| `formatNumber` | Formats a number to N decimal places (0–10) |

All tools are pure functions with no side effects.

## Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `serverURL` | `String` | — | Full URL of an Open Responses API endpoint |
| `modelName` | `String` | — | Model identifier |
| `apiKey` | `String?` | `nil` | Optional API key |
| `maxRetries` | `Int` | `3` | LLM call retry attempts |

## Transcript Example

```
[user]       What is 144 / 12?
[toolCall]   calculate({"expression":"144 / 12"})
[toolResult] calculate → 12.0 (0.001s)
[assistant]  144 divided by 12 equals 12.
```

## Errors

| Case | Thrown when |
|------|------------|
| `ToolUsingAgentError.emptyGoal` | `goal` is empty |
| `ToolUsingAgentError.invalidServerURL` | URL is invalid |
| `ToolUsingAgentError.noResponseContent` | LLM final response is empty |
| `ToolUsingAgentError.toolCallFailed(String)` | A tool execution failed |
| `ToolUsingAgentError.unknownTool(String)` | LLM requested an unregistered tool |
| `ToolUsingAgentError.toolLoopExceeded` | More than 10 dispatch iterations |

## Testing

```bash
swift test --filter ToolUsingAgentTests
```

Tests include direct tool unit tests (calculator, converter, formatter) and agent state validation.

## File Structure

```
Agents/ToolUsingAgent/
├── specs/
│   ├── SPEC.md
│   └── Overview.md
├── README.md
├── Sources/
│   └── ToolUsingAgent.swift
├── CLI/
│   └── ToolUsingAgentCLI.swift
└── Tests/
    └── ToolUsingAgentTests.swift
```

## Related

- [specs/SPEC.md](specs/SPEC.md) — agent specification
- [specs/Overview.md](specs/Overview.md) — generation rules
- [LLMChat](../LLMChat/README.md) — base agent without tools
- [Root README.md](../../README.md) — project overview
