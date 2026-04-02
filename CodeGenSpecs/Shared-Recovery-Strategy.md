# Shared Spec: Recovery Strategies

> Resilience trait — self-healing from context overflow, output truncation, and API errors.

---

## Summary

Recovery strategies handle errors that are recoverable by adjusting the agent's approach rather than retrying the same operation. This is distinct from `retryWithBackoff` (transport-level retries) — recovery strategies modify the agent state to avoid the same error on the next attempt.

---

## Core Types

### RecoverableError

```swift
public enum RecoverableError: Sendable {
    case contextWindowExceeded     // prompt + context too large
    case outputTruncated           // response cut off by max_tokens
    case apiError(statusCode: Int, message: String)
}
```

### RecoveryStrategy Protocol

```swift
public protocol RecoveryStrategy: Sendable {
    func attemptRecovery(
        from error: RecoverableError,
        state: inout RecoveryState
    ) async -> RecoveryResult
}
```

### RecoveryResult

```swift
public enum RecoveryResult: Sendable {
    case recovered(continuationPrompt: String?)   // try again with optional modified prompt
    case cannotRecover
}
```

### RecoveryState

```swift
public struct RecoveryState: Sendable {
    public var attemptedStrategies: Set<String>
    public var transcript: [TranscriptEntry]
    public var tokenBudget: ContextBudget?
}
```

Tracks which strategies have been tried to avoid infinite loops.

---

## Built-in Strategies

### ReactiveCompactionStrategy

Compresses the transcript when context window is exceeded. Uses the configured `TranscriptCompressor` to reduce token usage, then retries.

### OutputTokenEscalationStrategy

Increases `max_tokens` on the next request when output is truncated. Escalates progressively (e.g., 1024 → 2048 → 4096).

### ContinuationStrategy

Sends a continuation prompt ("Please continue from where you left off.") when output is truncated, preserving the partial response.

### RecoveryChain

```swift
public struct RecoveryChain: Sendable {
    public init(_ strategies: [any RecoveryStrategy])
    public func recover(from error: RecoverableError, state: inout RecoveryState) async -> RecoveryResult
}
```

Tries strategies in order. First `.recovered` result wins. If all return `.cannotRecover`, the error propagates.

---

## Error Classification

```swift
public func classifyRecoverableError(_ error: Error) -> RecoverableError?
public func classifyAPIError(_ error: Error) -> APIErrorCategory

public enum APIErrorCategory: Sendable {
    case auth, quota, rateLimit(retryAfterSeconds: Int?), connectivity, serverError, badRequest, unknown
}

public enum ToolErrorCategory: Sendable {
    case inputDecoding, executionFailure, timeout, permissionDenied, unknown
}
```

---

## Usage Pattern

```swift
let chain = RecoveryChain([
    ReactiveCompactionStrategy(),
    OutputTokenEscalationStrategy(),
    ContinuationStrategy(),
])

// In agent tool loop:
do {
    let response = try await llmClient.send(request)
} catch {
    if let recoverable = classifyRecoverableError(error) {
        let result = await chain.recover(from: recoverable, state: &recoveryState)
        if case .recovered(let prompt) = result {
            // retry with modified state
        }
    }
    throw error
}
```

---

## Integration Points

- **AgentToolLoop**: invokes recovery chain on recoverable errors before failing
- **Retry Strategy**: recovery happens *after* transport retries are exhausted
- **Context Management**: `ReactiveCompactionStrategy` delegates to `TranscriptCompressor`
- **Telemetry**: recovery attempts emit telemetry events
- If the Resilience trait is disabled, recovery compiles to no-op (always `.cannotRecover`).
