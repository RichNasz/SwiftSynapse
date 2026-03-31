# Code Generation Overview: ToolUsingAgent

> Instructs the code generator on what files to produce and how to assemble them from SPEC.md and shared CodeGenSpecs.

---

## Files to Generate

| File | Target | Purpose |
|------|--------|---------|
| `Sources/ToolUsingAgent.swift` | `ToolUsingAgentAgent` library | Main actor + tool implementations + error enum |
| `CLI/ToolUsingAgentCLI.swift` | `tool-using-agent` executable | ArgumentParser CLI |
| `Tests/ToolUsingAgentTests.swift` | `ToolUsingAgentTests` test target | Swift Testing suite |

---

## Shared Types Used

- `AgentConfiguration` — centralized config with validation
- `Agent` — from SwiftOpenResponsesDSL; handles the full tool dispatch loop, parallel tool execution, conversation continuity
- `AgentTool` — from SwiftOpenResponsesDSL; pairs `FunctionToolParam` definition with handler closure
- `retryWithBackoff` — **shared free function** wrapping `agent.send()` with `agent.reset()` before each attempt
- `@SpecDrivenAgent` macro — generates `_status`, `_transcript`, `status`, `transcript`
- `AgentConfigurationError` — replaces per-agent `invalidServerURL` case

---

## Shared Specs to Apply

1. `Shared-Configuration.md` — `AgentConfiguration` init pattern
2. `Shared-Retry-Strategy.md` — `retryWithBackoff` wrapping Agent.send()
3. `Shared-Transcript.md` — transcript synced from Agent via `_transcript.sync(from:)`
4. `Shared-Error-Strategy.md` — error enum placement, status-before-throw invariant

---

## Actor State Properties

```swift
@SpecDrivenAgent
public actor ToolUsingAgent {
    private let config: AgentConfiguration

    private static let maxToolIterations = 10
}
```

---

## Init Rules

1. Primary init takes `AgentConfiguration` (already validated).
2. No stored `_llmClient` — client built fresh in `execute()` for Agent construction.
3. Legacy convenience init `(serverURL:modelName:apiKey:maxRetries:)` creates an `AgentConfiguration` and delegates.

---

## execute() Rules

1. Guard non-empty goal → `.emptyGoal` error.
2. `_status = .running`; `_transcript.reset()`.
3. Build `Agent` with `@AgentToolBuilder`:
   - Register calculate, convertUnit, formatNumber tools via `AgentTool(tool:handler:)`
   - Set `maxToolIterations: 10`
4. Call `retryWithBackoff(maxAttempts: config.maxRetries)` wrapping `agent.send(goal)`, calling `agent.reset()` before each attempt.
5. Guard non-empty result → `.noResponseContent` error.
6. Sync transcript from Agent; `_status = .completed(result)`; return.

The Agent handles the entire tool dispatch loop internally — no manual iteration needed.

---

## Tool Dispatch

`dispatchTool` is a **static** method — all three tools (calculate, convertUnit, formatNumber) are pure functions registered via `AgentTool` closures.

---

## CLI Rules

Uses `AgentConfiguration.fromEnvironment(overrides:)` — `--server-url` and `--model` are optional, falling back to `SWIFTSYNAPSE_*` environment variables.

---

## Test Rules

1. `toolUsingAgentInitThrowsOnInvalidURL` — invalid URL → `AgentConfigurationError`
2. `toolUsingAgentThrowsOnEmptyGoal` — empty goal → `.emptyGoal` error
3. `toolUsingAgentInitialStateIsIdle` — `.idle` status, 0 entries
4. `calculatorToolReturnsResult` / `calculatorToolDivision` — direct tool tests
5. `converterToolMilesToKilometers` / `converterToolCelsiusToFahrenheit` — unit conversion
6. `converterToolInvalidUnitThrows` — unknown unit → `.toolCallFailed`
7. `formatNumberTool` / `formatNumberToolClamps` — formatting + clamping
