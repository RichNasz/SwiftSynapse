# Shared Spec: Retry Strategy

> Defines how SwiftSynapse agents handle transient LLM and network failures with exponential backoff and observable retry annotations.

---

## Summary

Agents that call `LLMClient.send()` wrap the call in a `retryWithBackoff` helper. Retries are transparent to the caller, annotated in the transcript, and bounded by a configurable maximum. Terminal errors (input validation, empty responses) are never retried.

---

## Retry Helper

The retry helper is a free `async` function defined in `SwiftSynapseMacrosClient` (or a shared utilities module available to all agents):

```swift
public func retryWithBackoff<T: Sendable>(
    maxAttempts: Int = 3,
    baseDelay: Duration = .milliseconds(500),
    isRetryable: @Sendable (Error) -> Bool = isTransportRetryable,
    onRetry: (@Sendable (Error, Int) -> Void)? = nil,
    operation: @Sendable () async throws -> T
) async throws -> T {
    var lastError: Error?
    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch {
            lastError = error
            guard isRetryable(error), attempt < maxAttempts else {
                throw error
            }
            onRetry?(error, attempt)
            let delay = baseDelay * Double(1 << (attempt - 1))  // 500ms, 1s, 2s
            try await Task.sleep(for: delay)
        }
    }
    throw lastError!
}
```

The `onRetry` callback receives the error and the **just-failed** attempt number (1-indexed). It is called **before** the delay sleep, so agents can append transcript annotations before the pause. The next attempt number is `attempt + 1`.

Agents do **not** define this function themselves — it is provided by the shared library. Agents only call it.

---

## Retryable Conditions

The default `isTransportRetryable` predicate returns `true` for:

| Error | Reason |
|-------|--------|
| `URLError.timedOut` | Transient timeout |
| `URLError.networkConnectionLost` | Network drop |
| `URLError.notConnectedToInternet` | Network unavailable |
| HTTP 429 (rate limit) | Server-side throttle |
| HTTP 503 (service unavailable) | Temporary server overload |

**On-device errors** (Foundation Models framework, see `Shared-Foundation-Models.md`):

| Error | Retryable? | Reason |
|-------|-----------|--------|
| `FoundationModelsError.generationTimeout` | Yes | Transient on-device timeout |
| `FoundationModelsError.frameworkError` | Yes | Unknown, may be transient |
| `FoundationModelsError.modelNotAvailable` | No | Permanent on this device (use fallback instead) |
| `FoundationModelsError.guardrailViolation` | No | Content issue — retry won't help |
| `FoundationModelsError.unsupportedCapability` | No | Permanent capability gap |

In hybrid mode, retry happens **before** fallback. If all retries fail with a retryable error, and the final error is fallback-eligible (see `Shared-Foundation-Models.md`), the `HybridLLMClient` attempts the cloud path. The cloud call is then subject to its own retry cycle.

All other errors return `false`. In particular, the following are **never retried**:
- `emptyGoal`, `invalidConfiguration`, `noResponseContent` — caller errors
- HTTP 400, 401, 403, 404 — permanent API errors
- `DecodingError` — malformed response (not a transient failure)

---

## Usage Pattern in execute()

Wrap only the `LLMClient.send()` call, not the entire `execute()` body:

```swift
public func execute(goal: String) async throws -> String {
    guard !goal.isEmpty else {
        let e = MyAgentError.emptyGoal
        _status = .error(e)
        throw e
    }
    _status = .running
    _transcript.append(.userMessage(goal))

    let request = try ResponseRequest(model: modelName) { ... } input: { User(goal) }

    let response: Response
    do {
        response = try await retryWithBackoff(maxAttempts: maxRetries) {
            try await _llmClient.send(request)
        }
    } catch {
        _status = .error(error)
        throw error
    }

    let text = response.firstOutputText ?? ""
    guard !text.isEmpty else {
        let e = MyAgentError.noResponseContent
        _status = .error(e)
        throw e
    }

    _transcript.append(.assistantMessage(text))
    _status = .completed(text)
    return text
}
```

The `maxRetries` value comes from `AgentConfiguration` (see `Shared-Configuration.md`), defaulting to 3.

---

## Transcript Annotations

When a retry occurs, append a `.reasoning` entry via the `onRetry` callback so the transcript is observable:

```swift
response = try await retryWithBackoff(
    maxAttempts: maxRetries,
    onRetry: { [self] error, failedAttempt in
        let nextAttempt = failedAttempt + 1
        _transcript.append(.reasoning("Retrying LLM call (attempt \(nextAttempt) of \(maxRetries))…"))
    }
) {
    try await _llmClient.send(request)
}
```

The `onRetry` callback receives the **just-failed** attempt number (1-indexed). The next attempt is `failedAttempt + 1`. The callback runs **before** the backoff delay sleep.

The `.reasoning` entry content is fixed — it does not include the error message (which may contain user content or server details).

---

## maxRetries Configuration

- Default: `3` (from `AgentConfiguration.maxRetries`)
- Range: `1...10` (enforced at configuration validation time)
- `maxRetries = 1` means no retry (one attempt, then throw)
- `maxRetries = 0` is invalid and rejected during `AgentConfiguration` init

Agents read this value from their stored configuration:

```swift
private let maxRetries: Int  // set from AgentConfiguration.maxRetries at init

public init(configuration: AgentConfiguration) throws {
    // ...
    self.maxRetries = configuration.maxRetries
}
```

---

## What Is Never Retried

- Input validation (`emptyGoal`, `invalidConfiguration`) — checked before the retry wrapper
- Response content validation (`noResponseContent`) — checked after the retry wrapper
- Tool calls — each tool manages its own failure handling; the retry layer does not wrap tool dispatch
- Second-leg LLM calls (e.g., persona rewrite in `LLMChatPersonas`) — each `_llmClient.send()` call is independently wrapped, not the overall pipeline
