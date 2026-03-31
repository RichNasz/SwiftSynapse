# Code Generation Overview: StreamingChatAgent

> Instructs the code generator on what files to produce and how to assemble them from SPEC.md and shared CodeGenSpecs.

---

## Files to Generate

| File | Target | Purpose |
|------|--------|---------|
| `Sources/StreamingChatAgent.swift` | `StreamingChatAgentAgent` library | Main actor + error enum |
| `CLI/StreamingChatAgentCLI.swift` | `streaming-chat-agent` executable | ArgumentParser CLI with live streaming output |
| `Tests/StreamingChatAgentTests.swift` | `StreamingChatAgentTests` test target | Swift Testing suite |
| `README.md` | documentation | Agent README per `Agent-README-Generation.md` |

---

## Shared Specs to Apply

Apply all of the following (in order):

1. `Shared-Observability.md` — `AgentContext`, status transitions
2. `Shared-Transcript.md` — **streaming lifecycle** is the core pattern for this agent; follow exactly
3. `Shared-Error-Strategy.md` — error enum placement (top-level), status-before-throw invariant
4. `Shared-Configuration.md` — `AgentConfiguration` init pattern
5. `Shared-Telemetry.md` — emit `agentStarted`, `agentCompleted`, `agentFailed`, `llmCallMade`

Do NOT apply:
- `Shared-Retry-Strategy.md` — no retry on streaming calls (see SPEC.md)
- `Shared-Tool-Registry.md` — no tools
- `Shared-Tool-Concurrency.md` — no tools
- `Shared-Background-Execution.md` — no background execution
- `Shared-Session-Resume.md` — no session resume

---

## Actor State Properties

```swift
@SpecDrivenAgent
public actor StreamingChatAgent {
    private let modelName: String
    private let _llmClient: LLMClient
    private var _agentContext = AgentContext()
}
```

No additional stored properties.

---

## Init Rules

```swift
public init(configuration: AgentConfiguration) throws {
    self.modelName = configuration.modelName
    self._llmClient = try LLMClient(
        baseURL: configuration.serverURL,
        apiKey: configuration.apiKey ?? ""
    )
}
```

---

## execute() Rules

The key difference from `LLMChat` is the streaming API call. Use `_llmClient.stream(request)` (or equivalent streaming method provided by `SwiftOpenResponsesDSL`) instead of `_llmClient.send(request)`.

```swift
public func execute(goal: String) async throws -> String {
    guard !goal.isEmpty else {
        let e = StreamingChatAgentError.emptyGoal
        _status = .error(e)
        throw e
    }
    _agentContext = AgentContext()
    _status = .running
    emit(.agentStarted(agentType: "StreamingChatAgent"))
    _transcript.append(.userMessage(goal))

    let request = try ResponseRequest(model: modelName) {
        try RequestTimeout(configuration.timeoutSeconds)
        try ResourceTimeout(configuration.timeoutSeconds)
        try StreamingEnabled()   // DSL config for streaming
    } input: {
        User(goal)
    }

    try Task.checkCancellation()

    let stream = try await _llmClient.stream(request)
    _transcript.setStreaming(true)
    var accumulated = ""

    do {
        for try await chunk in stream {
            accumulated += chunk
            _transcript.appendDelta(chunk)
        }
    } catch {
        _transcript.setStreaming(false)
        _status = .error(error)
        emit(.agentFailed(agentType: "StreamingChatAgent", durationMs: elapsed(_agentContext.startTime), errorType: String(describing: type(of: error))))
        throw error
    }

    _transcript.setStreaming(false)

    guard !accumulated.isEmpty else {
        let e = StreamingChatAgentError.noResponseContent
        _status = .error(e)
        emit(.agentFailed(agentType: "StreamingChatAgent", durationMs: elapsed(_agentContext.startTime), errorType: "noResponseContent"))
        throw e
    }

    _transcript.append(.assistantMessage(accumulated))
    _status = .completed(accumulated)
    emit(.agentCompleted(agentType: "StreamingChatAgent", durationMs: elapsed(_agentContext.startTime), inputTokens: _agentContext.totalInputTokens, outputTokens: _agentContext.totalOutputTokens))
    return accumulated
}
```

**Critical:** The `setStreaming(false)` in the `catch` block must come before `_status = .error(...)`. Do not swap these.

---

## CLI Rules

The CLI should print chunks as they arrive, not buffer the full response:

```swift
func run() async throws {
    let config = try AgentConfiguration.fromEnvironment(overrides: .init(
        serverURL: serverURL, modelName: model, apiKey: apiKey
    ))
    let agent = try StreamingChatAgent(configuration: config)

    // Observe streaming text using Observation framework
    // Since CLI is not SwiftUI, use withObservationTracking or directly call execute()
    // For simplicity, execute() accumulates internally and print is called on completion
    let result = try await agent.execute(goal: goal)
    print(result)
}
```

If `SwiftOpenResponsesDSL` exposes a way to hook per-chunk output for CLI use, use it. Otherwise, the CLI prints the full result after completion — the streaming UX is a SwiftUI concern.

---

## Test Rules

Tests must cover:
1. `streamingChatAgentThrowsOnEmptyGoal` — empty goal → `.emptyGoal` error, status `.error`
2. `streamingChatAgentInitialStateIsIdle` — fresh instance has `.idle` status, 0 entries
3. `streamingChatAgentIsStreamingFalseAfterCompletion` — after a mock streaming execute completes, `agent.transcript.isStreaming == false`
4. `streamingChatAgentStreamingTextEmptyAfterCompletion` — after completion, `agent.transcript.streamingText == ""`
5. `streamingChatAgentTranscriptHasTwoEntries` — after completion, transcript has exactly 2 entries

For tests 3–5: inject a mock `LLMClient` (via `configure(client:)`) that returns a mock `AsyncThrowingStream` with 3 chunks. Verify the post-execution state without a live server.
