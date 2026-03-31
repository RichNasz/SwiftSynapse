# Shared Spec: Telemetry

> Defines the lightweight, opt-in telemetry model for SwiftSynapse agents — covering event types, the deferred sink pattern, and privacy rules.

---

## Summary

Agents emit structured telemetry events for performance measurement, token cost tracking, and error rate monitoring. Telemetry is **opt-in**: no events are emitted unless the caller injects a sink. Events never include user-supplied content (goals, LLM responses, tool arguments).

---

## TelemetryEvent

```swift
public enum TelemetryEvent: Sendable {
    /// Agent started executing a goal.
    /// - agentType: the Swift type name of the actor (e.g. "LLMChat")
    /// - Note: goal string is intentionally omitted (user content)
    case agentStarted(agentType: String)

    /// Agent completed successfully.
    case agentCompleted(agentType: String, durationMs: Int, inputTokens: Int, outputTokens: Int)

    /// Agent failed with an error.
    /// - errorType: type(of: error) string only, never the error message
    case agentFailed(agentType: String, durationMs: Int, errorType: String)

    /// One LLM inference call was made (cloud or on-device).
    case llmCallMade(model: String, inputTokens: Int, outputTokens: Int, durationMs: Int, executionMode: ExecutionMode)

    /// On-device call failed and fell back to cloud in hybrid mode.
    case hybridFallback(agentType: String, onDeviceError: String, durationMs: Int)

    /// A tool was dispatched and returned.
    /// - toolName: name of the tool (not arguments or results)
    case toolCalled(toolName: String, durationMs: Int, succeeded: Bool)

    /// A retry was attempted.
    case retryAttempted(agentType: String, attempt: Int, maxAttempts: Int)
}
```

Privacy rules enforced at the type level:
- Goal strings are never in any event case.
- LLM response text is never in any event case.
- Tool arguments and results are never in any event case.
- Tool names, agent type names, and model names are considered safe metadata.

---

## TelemetrySink Protocol

```swift
public protocol TelemetrySink: AnyObject, Sendable {
    func record(_ event: TelemetryEvent)
}
```

- Synchronous (`func`, not `async func`) — the agent must not block on telemetry.
- Implementations are responsible for their own batching, persistence, or forwarding.
- A no-op implementation (`NullTelemetrySink`) is provided by `SwiftSynapseMacrosClient` for testing.

---

## Agent Integration

Agents hold an optional weak reference to a sink. The `@SpecDrivenAgent` macro generates the `_telemetrySink` backing store and the `configure(telemetry:)` method:

```swift
// Macro-generated (do not write manually)
private weak var _telemetrySink: (any TelemetrySink)?
public func configure(telemetry sink: any TelemetrySink) {
    _telemetrySink = sink
}
```

Agents emit events via a private helper:

```swift
private func emit(_ event: TelemetryEvent) {
    _telemetrySink?.record(event)
}
```

If `_telemetrySink` is `nil`, `emit` is a no-op. There is no queuing or buffering in agents — dropped events are simply dropped.

---

## Emission Points

| Event | When to emit |
|-------|-------------|
| `agentStarted` | At the top of `execute()`, after input validation passes |
| `agentCompleted` | Immediately before `return` in the success path |
| `agentFailed` | Once per `execute()` invocation, in the outermost error path before the throw propagates. Emit only once — not in inner catch blocks that will rethrow to an outer handler. |
| `llmCallMade` | Immediately after each `_llmClient.send()` returns successfully, before any response validation. Measure `durationMs` from the start of the `send()` call to its return. |
| `toolCalled` | After each tool dispatch completes (success or failure) |
| `retryAttempted` | Inside the `retryWithBackoff` `onRetry` callback |

Duration is measured via `ContinuousClock` from the call start to the return/throw.

---

## AgentContext for Accumulation

Token counts and durations accumulate in `AgentContext`, the non-reactive session metadata struct defined in `Shared-Observability.md`. **Do not redefine this struct** — it is the single definition shared across observability, telemetry, and session resume specs.

The telemetry-relevant fields are:
- `startTime` — used to compute `durationMs` for all telemetry events
- `totalInputTokens` / `totalOutputTokens` — accumulated from each API response
- `llmCallCount` / `toolCallCount` — incremented after each respective call

Token values are extracted from the API response object (fields provided by `SwiftOpenResponsesDSL.Response`).

---

## Example Usage (Caller Side)

```swift
class AppTelemetry: TelemetrySink {
    func record(_ event: TelemetryEvent) {
        switch event {
        case .agentCompleted(let type, let durationMs, let input, let output):
            MetricsKit.emit("agent.duration", value: durationMs, tags: ["agent": type])
            MetricsKit.emit("agent.tokens.input", value: input, tags: ["agent": type])
        case .agentFailed(let type, _, let errorType):
            MetricsKit.increment("agent.errors", tags: ["agent": type, "error": errorType])
        default:
            break
        }
    }
}

let agent = try LLMChat(configuration: config)
await agent.configure(telemetry: AppTelemetry())
```

---

## What Telemetry Is Not

- Not a replacement for `ObservableTranscript` — telemetry is for operational metrics, transcript is for conversation history.
- Not a logging system — agents may also use `os_log` or `Logger` separately.
- Not always-on — the nil sink path has zero overhead beyond a nil check.
