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
| `_telemetrySink` | `(any TelemetrySink)?` | private | Optional weak telemetry sink (see `Shared-Telemetry.md`) |
| `configure(telemetry:)` | method | public | Inject a telemetry sink |
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

---

## AgentContext (Non-Reactive Session Metadata)

`_status` and `_transcript` are reactive: changes to them trigger `@Observable` diffing and SwiftUI view updates. Session metadata (start time, token counts, retry count, step index) must not trigger reactive diffing — every token arrival would cause unnecessary view updates.

Agents that track session metadata maintain a private `AgentContext` value type:

```swift
private struct AgentContext {
    var startTime: ContinuousClock.Instant = .now
    var totalInputTokens: Int = 0
    var totalOutputTokens: Int = 0
    var llmCallCount: Int = 0
    var toolCallCount: Int = 0
    var completedStepIndex: Int = -1  // -1 = no steps completed yet
}

private var _agentContext = AgentContext()
```

`AgentContext` is a plain struct stored as a `var` in the actor. It is not `@Observable`. It accumulates values freely during `execute()` and is reset at the top of each new `execute()` call:

```swift
public func execute(goal: String) async throws -> String {
    _agentContext = AgentContext()
    // ...
}
```

Agents that support telemetry (`Shared-Telemetry.md`) read token counts from `_agentContext` when emitting `agentCompleted` events. Agents that support session resume (`Shared-Session-Resume.md`) read `completedStepIndex` from `_agentContext` when snapshotting.

---

## Typed Progress Data

`TranscriptEntry.toolCall` and `TranscriptEntry.toolResult` carry structured payloads (defined in `Shared-Transcript.md`). For the observable status, `AgentStatus.running` is a simple case — UIs that need richer in-progress detail should observe `_transcript.entries.last` to determine what the agent is currently doing.

The convention for "what is the agent doing right now" is: the most recently appended transcript entry describes the current activity. UIs map entry types to display strings:

| Last entry type | Display |
|----------------|---------|
| `.userMessage` | "Processing goal…" |
| `.toolCall(name:)` | "Calling \(name)…" |
| `.assistantMessage` | "Received response" |
| `.reasoning` | "Thinking…" |

This avoids a separate "current activity" observable and keeps the transcript as the single source of truth.

---

## Status Transition Rules

Valid transitions:

| From | To | When |
|------|----|------|
| `.idle` | `.running` | `execute()` begins after successful input validation |
| `.running` | `.completed(result)` | `execute()` returns a value |
| `.running` | `.error(e)` | `execute()` throws (always set status before throwing) |
| `.running` | `.paused` | Agent checkpoints during background execution |
| `.paused` | `.running` | Agent resumes from a checkpoint |
| `.error(e)` | `.idle` | Caller explicitly resets the agent |
| `.completed` | `.idle` | Caller explicitly resets the agent |

Invalid transitions (never generate code that produces these):
- `.idle → .completed` (skipped execution)
- `.idle → .error` (no error can occur before running)
- `.completed → .running` (use a new instance or call `reset()`)
- `.error → .running` (use a new instance or call `reset()`)

Agents do not expose a `reset()` method by default. If a spec requires one, it is explicitly declared in that agent's `Overview.md`.

---

## Observable Binding in SwiftUI

SwiftUI views observe agents directly via `@State` or `@Environment`:

```swift
// In a SwiftUI view
@State private var agent = SimpleEcho()

var body: some View {
    VStack {
        // Reacts to _status changes
        switch agent.status {
        case .idle: Text("Ready")
        case .running: ProgressView()
        case .completed(let r): Text(r as! String)
        case .error(let e): Text("Error: \(e)")
        case .paused: Text("Paused")
        }

        // Reacts to _transcript changes
        ForEach(agent.transcript.entries.indices, id: \.self) { i in
            TranscriptEntryView(entry: agent.transcript.entries[i])
        }

        // Streaming partial text
        if agent.transcript.isStreaming {
            Text(agent.transcript.streamingText)
                .foregroundStyle(.secondary)
        }
    }
}
