# Shared Spec: Observability

> Defines how every SwiftSynapse agent exposes its internal state and transcript to the rest of the app.

---

## Summary

All agent actors use the `@SpecDrivenAgent` macro, which generates observable state via the Swift Observation framework. SwiftUI views bind directly to agent properties without Combine or `ObservableObject`.

### Macro-Generated Observable Members

The `@SpecDrivenAgent` macro generates the following members on every agent actor:

| Member | Type | Access | Purpose |
|--------|------|--------|---------|
| `_status` | `AgentStatus` | private | Backing storage for agent lifecycle state |
| `_transcript` | `ObservableTranscript` | private | Backing storage for conversation history |
| `_client` | `LLMClient?` | private | Optional LLM client (injected via `configure(client:)`) |
| `status` | `AgentStatus` | read-only | Public accessor for current status |
| `transcript` | `ObservableTranscript` | read-only | Public accessor for transcript |
| `client` | `LLMClient` | read-only | Public accessor (fatalError if not configured) |
| `configure(client:)` | method | public | Inject an LLM client |
| `run(goal:)` | method | public | Generic runtime loop via `AgentRuntime` |

### AgentStatus

```swift
public enum AgentStatus: @unchecked Sendable {
    case idle
    case running
    case paused
    case error(Error)
    case completed(Any)
}
```

Agents set status via `_status` directly within the actor:
- `.idle` — initial state
- `.running` — execution in progress
- `.error(someError)` — failed with associated error
- `.completed(result)` — finished with associated result value

### ObservableTranscript

`ObservableTranscript` is an `@Observable` class (`@unchecked Sendable`) that wraps conversation entries:

```swift
@Observable
public final class ObservableTranscript: @unchecked Sendable {
    public private(set) var entries: [TranscriptEntry]
    public private(set) var isStreaming: Bool
    public private(set) var streamingText: String

    public func append(_ entry: TranscriptEntry)
    public func setStreaming(_ streaming: Bool)
    public func appendDelta(_ text: String)
    public func reset()
}
```

SwiftUI views access `agent.transcript.entries` for the conversation history. Streaming state is managed via `setStreaming()` and `appendDelta()`.

### Agent-Specific Logic

Agents implement their domain logic in a custom `execute(goal:)` method (or similar), separate from the macro-generated `run(goal:)`. The custom method accesses `_status` and `_transcript` directly as private members within the actor.

[Detailed rules to be expanded]
