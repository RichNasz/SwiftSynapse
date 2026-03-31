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

- `AgentConfiguration` — centralized config with validation; replaces inline URL validation
- `retryWithBackoff` — **shared free function** wrapping each `_llmClient.send()` call
- `ToolExecutor` — **shared actor** for concurrent tool execution with result ordering
- `@SpecDrivenAgent` macro — generates `_status`, `_transcript`, `status`, `transcript`, `run(goal:)`
- `LLMClient` — via `config.buildLLMClient()`
- `AgentConfigurationError` — replaces per-agent `invalidServerURL` case

---

## Shared Specs to Apply

1. `Shared-Configuration.md` — `AgentConfiguration` init pattern
2. `Shared-Retry-Strategy.md` — `retryWithBackoff` wrapping each LLM call
3. `Shared-Tool-Concurrency.md` — `ToolExecutor.execute()` for tool dispatch
4. `Shared-Transcript.md` — entry payloads, ordering guarantee
5. `Shared-Error-Strategy.md` — error enum placement, status-before-throw invariant

---

## Actor State Properties

```swift
@SpecDrivenAgent
public actor ToolUsingAgent {
    private let config: AgentConfiguration
    private let _llmClient: LLMClient

    private static let maxToolIterations = 10
}
```

---

## Init Rules

1. Primary init takes `AgentConfiguration` (already validated).
2. `_llmClient = try configuration.buildLLMClient()`.
3. Legacy convenience init `(serverURL:modelName:apiKey:maxRetries:)` creates an `AgentConfiguration` and delegates.

---

## execute() Rules

1. Guard non-empty goal → `.emptyGoal` error.
2. `_status = .running`; `_transcript.reset()`; append `.userMessage(goal)`.
3. Build `ResponseRequest` with `config.modelName`, `TimeInterval(config.timeoutSeconds)`, and tool definitions.
4. Dispatch loop up to `maxToolIterations = 10`:
   a. Call `retryWithBackoff(maxAttempts: config.maxRetries)` wrapping `_llmClient.send(request)`.
   b. If no tool calls: extract text, guard non-empty, return.
   c. Log all tool calls to transcript.
   d. Execute tools via `ToolExecutor.execute(calls:dispatch:)` with static `dispatchTool`.
   e. Log results to transcript; build `FunctionOutput` items.
   f. Build next request with `PreviousResponseId` for conversation threading.

---

## Tool Dispatch

`dispatchTool` is a **static** method — all three tools (calculate, convertUnit, formatNumber) are pure functions. All tools are `isConcurrencySafe: true` (default).

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
