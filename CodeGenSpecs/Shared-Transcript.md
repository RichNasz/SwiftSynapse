# Shared Spec: Transcript

> Defines the canonical transcript model used by all SwiftSynapse agents to record conversation history and streaming output.

---

## Summary

`ObservableTranscript` is the shared type that represents the full conversation between an agent and an LLM, including user turns, assistant turns, tool calls, and tool results. It is `@Observable` and `@unchecked Sendable`. New entries are appended via `append(_ entry:)`; the transcript entries array is never mutated directly by callers.

### TranscriptEntry

`TranscriptEntry` (defined in `SwiftOpenResponsesDSL`) is the unit of conversation:

```swift
public enum TranscriptEntry: Sendable {
    case userMessage(String)
    case assistantMessage(String)
    case reasoning(ReasoningItem)
    case toolCall(name: String, arguments: String)
    case toolResult(name: String, result: String, duration: Duration)
    case error(String)
}
```

### Streaming

Streaming deltas are managed via `ObservableTranscript`'s streaming methods:
- `setStreaming(true)` — marks the transcript as actively streaming
- `appendDelta(_ text:)` — accumulates partial text during streaming
- `setStreaming(false)` — ends streaming and clears `streamingText`

The agent folds each delta into the transcript in real time, so SwiftUI views always reflect the latest partial state without waiting for the full response.

### Usage in Agents

Agents access the transcript via the macro-generated `_transcript` backing property:

```swift
_transcript.append(.userMessage(goal))
// ... after LLM response ...
_transcript.append(.assistantMessage(responseText))
```

External consumers (SwiftUI views, tests) access it via the public `transcript` property:

```swift
let entries = await agent.transcript.entries
```

[Detailed rules to be expanded]
