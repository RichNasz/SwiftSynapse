# Shared Spec: Rate Limiting

> Resilience trait — rate-limit-aware retry with cooldown tracking.

---

## Summary

Extends the retry system (see `Shared-Retry-Strategy.md`) with rate-limit awareness. When the LLM API returns HTTP 429 with a `Retry-After` header, the agent respects the cooldown period before retrying.

---

## Core Types

### RateLimitState

```swift
public actor RateLimitState {
    public var retryAfterDate: Date?
    public var isInCooldown: Bool { get }
    public func update(retryAfter: TimeInterval)
    public func waitIfNeeded() async
}
```

### RateLimitPolicy

```swift
public struct RateLimitPolicy: Sendable {
    public let maxRetries: Int
    public let respectRetryAfter: Bool
    public let maxCooldownSeconds: TimeInterval     // cap on Retry-After
}
```

### retryWithRateLimit

```swift
public func retryWithRateLimit<T: Sendable>(
    state: RateLimitState,
    policy: RateLimitPolicy,
    operation: @Sendable () async throws -> T
) async throws -> T
```

Behaves like `retryWithBackoff` but additionally:
1. Parses `Retry-After` from HTTP 429 responses
2. Waits the specified cooldown before retrying
3. Caps cooldown at `maxCooldownSeconds` to prevent indefinite waits

---

## Integration Points

- **Retry Strategy**: `retryWithRateLimit` wraps `retryWithBackoff` with rate-limit awareness
- **AgentToolLoop**: uses rate-limit-aware retry for LLM calls
- **Telemetry**: emits `.retryAttempted` events with rate limit metadata
- If the Resilience trait is disabled, falls back to standard `retryWithBackoff`.
