# Code Generation Overview: ToolUsingAgent

> Instructs the code generator on what files to produce and how to assemble them from SPEC.md and shared CodeGenSpecs.

---

## Files to Generate

| File | Target | Purpose |
|------|--------|---------|
| `Sources/ToolUsingAgent.swift` | `ToolUsingAgentAgent` library | Main actor + tool implementations + error enum |
| `CLI/ToolUsingAgentCLI.swift` | `tool-using-agent` executable | ArgumentParser CLI |
| `Tests/ToolUsingAgentTests.swift` | `ToolUsingAgentTests` test target | Swift Testing suite |
| `README.md` | documentation | Agent README per `Agent-README-Generation.md` |

---

## Shared Specs to Apply

Apply all of the following (in order):

1. `Shared-Observability.md` — `AgentContext`, status transitions, SwiftUI binding
2. `Shared-Transcript.md` — entry payloads, ordering guarantee
3. `Shared-Error-Strategy.md` — error enum placement (top-level), status-before-throw invariant
4. `Shared-Configuration.md` — `AgentConfiguration` init pattern
5. `Shared-Retry-Strategy.md` — `retryWithBackoff` wrapping each `_llmClient.send()` call
6. `Shared-Tool-Registry.md` — `@LLMTool` declaration pattern
7. `Shared-Tool-Concurrency.md` — `ToolExecutor`, `isConcurrencySafe`, result budgeting, dispatch loop, `toolLoopExceeded` guard
8. `Shared-Telemetry.md` — optional sink, emit `agentStarted`, `agentCompleted`, `agentFailed`, `llmCallMade`, `toolCalled`

Do NOT apply:
- `Shared-Background-Execution.md` — no background execution for this agent
- `Shared-Session-Resume.md` — no session resume for this agent
- `Shared-LLM-Client.md` — superseded by `Shared-Configuration.md` for client initialization

---

## Actor State Properties

```swift
@SpecDrivenAgent
public actor ToolUsingAgent {
    private let modelName: String
    private let maxRetries: Int
    private let toolResultBudgetTokens: Int
    private let _llmClient: LLMClient
    private var _agentContext = AgentContext()

    // Tool implementations (private, called by dispatchTool)
    private let calculator = CalculatorTool()
    private let converter = UnitConverterTool()
    private let formatter = NumberFormatterTool()
}
```

Tool implementations are private nested types or extensions — the actor delegates to them from `dispatchTool`. They are `Sendable` structs.

---

## Init Rules

```swift
public init(configuration: AgentConfiguration) throws {
    self.modelName = configuration.modelName
    self.maxRetries = configuration.maxRetries
    self.toolResultBudgetTokens = configuration.toolResultBudgetTokens
    self._llmClient = try LLMClient(
        baseURL: configuration.serverURL,
        apiKey: configuration.apiKey ?? ""
    )
}
```

No URL validation in the actor — `AgentConfiguration.init()` already validates.

---

## execute() Rules

Follow the tool dispatch loop pattern in `Shared-Tool-Concurrency.md` exactly. Key points:

- The `ResponseRequest` config block registers all three tools: `calculate`, `convertUnit`, `formatNumber`.
- The dispatch loop runs up to `maxToolIterations = 10` times.
- `ToolExecutor.execute()` is called with the indexed tool calls from the LLM response.
- Transcript entries are appended in receive order after `ToolExecutor.execute()` returns.
- Each `_llmClient.send()` call is wrapped in `retryWithBackoff(maxAttempts: maxRetries)`.
- Token counts from each response are accumulated in `_agentContext`.

---

## dispatchTool() Rules

```swift
private func dispatchTool(name: String, arguments: String) async throws -> String {
    let start = ContinuousClock.now
    let result: String
    do {
        switch name {
        case "calculate":
            let args = try JSONDecoder().decode(CalculatorTool.Arguments.self, from: Data(arguments.utf8))
            result = try await calculator.call(args)
        case "convertUnit":
            let args = try JSONDecoder().decode(UnitConverterTool.Arguments.self, from: Data(arguments.utf8))
            result = try await converter.call(args)
        case "formatNumber":
            let args = try JSONDecoder().decode(NumberFormatterTool.Arguments.self, from: Data(arguments.utf8))
            result = try await formatter.call(args)
        default:
            throw ToolUsingAgentError.unknownTool(name)
        }
    } catch let e as ToolUsingAgentError {
        emit(.toolCalled(toolName: name, durationMs: elapsed(start), succeeded: false))
        throw e
    }
    let budgeted = budget(result, limit: toolResultBudgetTokens)
    emit(.toolCalled(toolName: name, durationMs: elapsed(start), succeeded: true))
    return budgeted
}
```

---

## Tool Implementation Rules

Each tool is a `Sendable` struct implementing a `call(_ args: Arguments) async throws -> String` method. Arguments type is `Codable` and `Sendable`. No tool stores state.

`CalculatorTool.call` uses `NSExpression(format:)` — wrap in a `do/catch` and throw `ToolUsingAgentError.toolCallFailed("calculate")` on any exception.

`UnitConverterTool.call` uses a hardcoded conversion table — see SPEC.md for supported units.

`NumberFormatterTool.call` uses `String(format:)` — clamp `decimalPlaces` to `0...10` before formatting.

---

## CLI Rules

```
swift run tool-using-agent "What is 25 times 4?" --server-url http://localhost:11434/v1 --model llama3
```

Options:
- `goal` — positional argument
- `--server-url` — optional if `SWIFTSYNAPSE_SERVER_URL` is set
- `--model` — optional if `SWIFTSYNAPSE_MODEL` is set
- `--api-key` — optional

Use `AgentConfiguration.fromEnvironment(overrides:)` in `run()`.

---

## Test Rules

Tests must cover:
1. `toolUsingAgentThrowsOnEmptyGoal` — empty goal → `.emptyGoal` error, status is `.error`
2. `toolUsingAgentInitialStateIsIdle` — fresh instance has `.idle` status, 0 transcript entries
3. `toolUsingAgentCalculatorToolReturnsResult` — directly test `CalculatorTool.call` with `"10 + 5"` → `"15.0"`
4. `toolUsingAgentConverterToolReturnsResult` — directly test `UnitConverterTool.call` with `100` miles to km
5. `toolUsingAgentUnknownToolThrows` — `dispatchTool(name: "bogus", arguments: "{}")` → `.unknownTool("bogus")`

Tests do not require a live LLM endpoint (all five tests exercise local logic only).
