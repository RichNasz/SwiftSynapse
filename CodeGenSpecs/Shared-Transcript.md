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

---

## TranscriptEntry Payload Details

Each `TranscriptEntry` case carries specific associated values:

| Case | Associated Values | Notes |
|------|------------------|-------|
| `.userMessage(String)` | The user's goal or follow-up | Always the first entry in a new execution |
| `.assistantMessage(String)` | The LLM's final text response | Never appended until streaming is complete |
| `.reasoning(ReasoningItem)` | A thinking step or retry annotation | Used for internal monologue and retry notices |
| `.toolCall(name: String, arguments: String)` | Tool name + raw JSON arguments string | Appended before tool execution starts |
| `.toolResult(name: String, result: String, duration: Duration)` | Tool name + result string + wall time | Appended after tool execution completes |
| `.error(String)` | Human-readable error description | Only used when an agent records an error in the transcript; most agents set `_status = .error(e)` instead |

The `arguments` string in `.toolCall` is the raw JSON string from the LLM — do not parse or pretty-print it. The `result` string in `.toolResult` is the (potentially budgeted) output from the tool.

---

## Streaming Lifecycle

The streaming lifecycle is:

```
setStreaming(true)      — called before the first token arrives
appendDelta(chunk)      — called for each token chunk received
                          (may be called 0–N times)
setStreaming(false)     — called when the stream closes or errors
append(.assistantMessage(fullText))  — called after setStreaming(false)
```

Full code pattern in a streaming agent:

```swift
_transcript.setStreaming(true)
var accumulated = ""

do {
    for try await chunk in streamingResponse {
        accumulated += chunk
        _transcript.appendDelta(chunk)
    }
} catch {
    _transcript.setStreaming(false)
    _status = .error(error)
    throw error
}

_transcript.setStreaming(false)
_transcript.append(.assistantMessage(accumulated))
```

Rules:
- `setStreaming(false)` is always called before `append(.assistantMessage(...))`.
- `setStreaming(false)` is called even on error — the `isStreaming` flag must never be `true` after `execute()` returns or throws.
- `streamingText` is cleared automatically by `setStreaming(false)`.
- If the LLM stream produces zero tokens (empty response), `appendDelta` is never called. `setStreaming(false)` is still called, followed by the `noResponseContent` guard check.

---

## Ordering Guarantees

In agents that execute multiple tools concurrently, transcript entries are always appended in **receive order** (the order the LLM issued the tool calls), not in completion order. The `ToolExecutor` (see `Shared-Tool-Concurrency.md`) handles this guarantee — all tool results are sorted by receive index before any transcript appending occurs.

This means:
- If the LLM requests `[toolA, toolB, toolC]` and `toolC` finishes first, the transcript still shows `toolA → toolB → toolC`.
- Agents must never append tool entries inside the tool's own execution closure — only after `ToolExecutor.execute()` returns.

---

## Transcript Integrity Rules

1. **Append-only**: `entries` is never mutated in place. No deletions, no edits, no reordering after appending.
2. **One active stream**: `setStreaming(true)` is never called while `isStreaming` is already `true`.
3. **Final message after stream**: `append(.assistantMessage(...))` is always called after `setStreaming(false)` — the final full text is always a discrete entry.
4. **Parallel agents share nothing**: Each agent instance owns its own `ObservableTranscript`. Transcripts are never merged or shared between instances.

---

## Testing Transcript Shape

Tests verify transcript shape by asserting on `entries.count` and matching specific index positions:

```swift
let entries = await agent.transcript.entries
#expect(entries.count == 2)

guard case .userMessage(let msg) = entries[0] else {
    Issue.record("Expected userMessage at index 0")
    return
}
#expect(msg == "hello")

guard case .assistantMessage(let reply) = entries[1] else {
    Issue.record("Expected assistantMessage at index 1")
    return
}
#expect(!reply.isEmpty)
