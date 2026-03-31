# Code Generation Overview: RetryingLLMChatAgent

> Instructs the code generator on what files to produce and how to assemble them from SPEC.md and shared CodeGenSpecs.

---

## Files to Generate

| File | Target | Purpose |
|------|--------|---------|
| `Sources/RetryingLLMChatAgent.swift` | `RetryingLLMChatAgentAgent` library | Main actor + error enum |
| `CLI/RetryingLLMChatAgentCLI.swift` | `retrying-llm-chat-agent` executable | ArgumentParser CLI |
| `Tests/RetryingLLMChatAgentTests.swift` | `RetryingLLMChatAgentTests` test target | Swift Testing suite |
| `README.md` | documentation | Agent README per `Agent-README-Generation.md` |

---

## Shared Specs to Apply

Apply all of the following (in order):

1. `Shared-Observability.md` — `AgentContext`, status transitions
2. `Shared-Transcript.md` — entry payloads, `.reasoning` for retry annotations
3. `Shared-Error-Strategy.md` — error enum (top-level), status-before-throw invariant, no retry on terminal errors
4. `Shared-Configuration.md` — `AgentConfiguration` init; `maxRetries` field is critical
5. `Shared-Retry-Strategy.md` — **this is the primary pattern** for this agent; follow exactly
6. `Shared-Telemetry.md` — emit `agentStarted`, `agentCompleted`, `agentFailed`, `llmCallMade`, `retryAttempted`

Do NOT apply:
- `Shared-Tool-Registry.md` — no tools
- `Shared-Tool-Concurrency.md` — no tools
- `Shared-Background-Execution.md` — no background execution
- `Shared-Session-Resume.md` — no session resume

---

## Actor State Properties

```swift
@SpecDrivenAgent
public actor RetryingLLMChatAgent {
    private let modelName: String
    private let maxRetries: Int
    private let _llmClient: LLMClient
    private var _agentContext = AgentContext()
}
```

---

## Init Rules

```swift
public init(configuration: AgentConfiguration) throws {
    self.modelName = configuration.modelName
    self.maxRetries = configuration.maxRetries
    self._llmClient = try LLMClient(
        baseURL: configuration.serverURL,
        apiKey: configuration.apiKey ?? ""
    )
}
```

---

## execute() Rules

The key difference from `LLMChat` is `retryWithBackoff` wrapping `_llmClient.send()`, plus the `annotateRetry` callback:

```swift
public func execute(goal: String) async throws -> String {
    guard !goal.isEmpty else {
        let e = RetryingLLMChatAgentError.emptyGoal
        _status = .error(e)
        throw e
    }
    _agentContext = AgentContext()
    _status = .running
    emit(.agentStarted(agentType: "RetryingLLMChatAgent"))
    _transcript.append(.userMessage(goal))

    let request = try ResponseRequest(model: modelName) {
        try RequestTimeout(300)
        try ResourceTimeout(300)
    } input: {
        User(goal)
    }

    try Task.checkCancellation()

    let response: Response
    do {
        let callStart = ContinuousClock.now
        response = try await retryWithBackoff(
            maxAttempts: maxRetries,
            baseDelay: .milliseconds(500),
            onRetry: { [self] error, failedAttempt in
                let nextAttempt = failedAttempt + 1
                _transcript.append(.reasoning("Retrying LLM call (attempt \(nextAttempt) of \(maxRetries))…"))
                emit(.retryAttempted(agentType: "RetryingLLMChatAgent", attempt: nextAttempt, maxAttempts: maxRetries))
            }
        ) {
            try await _llmClient.send(request)
        }
    } catch {
        _status = .error(error)
        emit(.agentFailed(agentType: "RetryingLLMChatAgent", durationMs: elapsed(_agentContext.startTime), errorType: String(describing: type(of: error))))
        throw error
    }

    let text = response.firstOutputText ?? ""
    guard !text.isEmpty else {
        let e = RetryingLLMChatAgentError.noResponseContent
        _status = .error(e)
        emit(.agentFailed(agentType: "RetryingLLMChatAgent", durationMs: elapsed(_agentContext.startTime), errorType: "noResponseContent"))
        throw e
    }

    let callEnd = ContinuousClock.now
    _agentContext.totalInputTokens += response.inputTokens
    _agentContext.totalOutputTokens += response.outputTokens
    emit(.llmCallMade(model: modelName, inputTokens: response.inputTokens, outputTokens: response.outputTokens, durationMs: Int((callEnd - callStart).components.seconds * 1000)))
    _transcript.append(.assistantMessage(text))
    _status = .completed(text)
    emit(.agentCompleted(agentType: "RetryingLLMChatAgent", durationMs: elapsed(_agentContext.startTime), inputTokens: _agentContext.totalInputTokens, outputTokens: _agentContext.totalOutputTokens))
    return text
}
```

The `onRetry` callback signature matches `Shared-Retry-Strategy.md`: it receives `(Error, Int)` where the `Int` is the just-failed attempt number (1-indexed). The next attempt number is `failedAttempt + 1`.

---

## CLI Rules

```
swift run retrying-llm-chat-agent "Hello, world." --server-url http://localhost:11434/v1 --model llama3
swift run retrying-llm-chat-agent "Hello" --max-retries 5   # optional override
```

Options:
- `goal` — positional
- `--server-url` — optional if env var set
- `--model` — optional if env var set
- `--api-key` — optional
- `--max-retries` — optional override for `AgentConfiguration.maxRetries`

---

## Test Rules

Tests must cover:
1. `retryingAgentThrowsOnEmptyGoal` — empty goal → `.emptyGoal`, status `.error`, `retryWithBackoff` never invoked
2. `retryingAgentInitialStateIsIdle` — fresh instance, `.idle` status, 0 transcript entries
3. `retryingAgentSucceedsWithOneRetry` — mock client fails on attempt 1, succeeds on attempt 2; transcript has 3 entries with `.reasoning` at index 1
4. `retryingAgentFailsAfterMaxRetries` — mock client fails all `maxRetries` attempts; error propagates, status `.error`
5. `retryingAgentNoRetryOnTerminalError` — configure `maxRetries = 3`; goal error fires before retry logic; transcript has 0 entries after throw

For tests 3–4: inject a mock `LLMClient` that counts calls and fails for the first N then succeeds (or always fails). The mock must be `Sendable` and injectable via `configure(client:)`.
