# Agent Spec: StreamingChatAgent

> Reference implementation for streaming LLM responses. Demonstrates the complete streaming transcript lifecycle: `setStreaming(true)` → `appendDelta` → `setStreaming(false)` → `.assistantMessage`.

---

## Goal

Accept a user prompt, stream the LLM response token-by-token into the transcript, and return the full accumulated response text. SwiftUI views observe `agent.transcript.streamingText` to display the live partial response and `agent.transcript.isStreaming` to show or hide a streaming indicator.

---

## Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `configuration` | `AgentConfiguration` | — | Server URL, model, API key, timeout, retry count |

Follows `Shared-Configuration.md`. No additional stored properties.

---

## Input

| Parameter | Type | Description |
|-----------|------|-------------|
| `goal` | `String` | The user's prompt |

---

## Tools

None. Streaming is demonstrated without tool calls to keep the spec unambiguous.

---

## Tasks (execute steps)

1. Validate `goal` is non-empty. Set `_status = .error(StreamingChatAgentError.emptyGoal)` and throw if empty.
2. Reset `_agentContext`. Set `_status = .running`. Emit `agentStarted`. Append `.userMessage(goal)`.
3. Build `ResponseRequest` with streaming enabled (`stream: true` in the DSL config block).
4. Check `Task.isCancelled` — throw `CancellationError` if cancelled.
5. Call `_llmClient.stream(request)` (the streaming variant of `send`) to get an `AsyncThrowingStream<String, Error>`.
6. Call `_transcript.setStreaming(true)`.
7. Iterate over the stream: for each `chunk`, call `_transcript.appendDelta(chunk)` and accumulate into a local `var accumulated = ""`.
8. On stream error: call `_transcript.setStreaming(false)`, set `_status = .error(e)`, emit `agentFailed`, throw.
9. After the stream closes: call `_transcript.setStreaming(false)`.
10. Guard `accumulated` is non-empty — throw `StreamingChatAgentError.noResponseContent` if empty.
11. Append `.assistantMessage(accumulated)`. Set `_status = .completed(accumulated)`. Emit `agentCompleted`. Return `accumulated`.

**Note:** There is no retry wrapper around the streaming call. Streaming connections that fail mid-stream are not retried (the partial response cannot be reliably reassembled). If the connection fails before the first token, the error propagates directly.

---

## Errors

```swift
public enum StreamingChatAgentError: Error, Sendable {
    case emptyGoal           // terminal
    case noResponseContent   // terminal — stream closed with zero tokens
}
```

---

## Output

The full accumulated LLM response as a `String`.

---

## Transcript Shape

Normal completion:
```
[0] .userMessage("Tell me a joke.")
[1] .assistantMessage("Why did the Swift developer cross the road? To get to the other side effect.")
```

During streaming (observable in real time via `agent.transcript`):
- `entries.count == 1` (only userMessage)
- `isStreaming == true`
- `streamingText == "Why did the Swift developer cross the road? To get..."` (partial)

After streaming completes:
- `entries.count == 2`
- `isStreaming == false`
- `streamingText == ""`

---

## Constraints

- Open Responses API only. The streaming API is the `/v1/responses` endpoint with `stream: true`.
- No tools, no background execution, no session resume.
- `setStreaming(false)` is always called — even on error. `isStreaming` must not be `true` after `execute()` returns or throws.
- No retry on the streaming call itself (see Tasks step note above).

---

## Success Criteria

1. `execute()` returns the full response text and status is `.completed`.
2. Transcript has exactly 2 entries: `.userMessage` at index 0, `.assistantMessage` at index 1.
3. `agent.transcript.isStreaming` is `false` after `execute()` returns.
4. `agent.transcript.streamingText` is `""` after `execute()` returns.
5. Empty goal throws `StreamingChatAgentError.emptyGoal` and status is `.error`.
6. If the stream errors mid-flight, `isStreaming` is `false` and status is `.error`.

---

## Platforms

iOS 26+, macOS 26+, visionOS 2.4+. Swift 6.2+ strict concurrency.
