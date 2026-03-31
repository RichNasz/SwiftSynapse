<!-- Generated from CodeGenSpecs/Agent-README-Generation.md + Agents/StreamingChatAgent/specs/SPEC.md — Do not edit manually. -->

# StreamingChatAgent

Stream an LLM response token-by-token with real-time transcript updates for SwiftUI.

## Overview

StreamingChatAgent accepts a user prompt, streams the LLM response token-by-token into the transcript, and returns the full accumulated response text. SwiftUI views observe `agent.transcript.streamingText` for live partial responses and `agent.transcript.isStreaming` for streaming indicators. This is the reference implementation for streaming in SwiftSynapse.

**Platforms:** iOS 26+, macOS 26+, visionOS 2.4+

## Quick Start

**CLI:**

```bash
swift run streaming-chat-agent "Tell me a joke." \
    --server-url http://127.0.0.1:1234/v1/responses \
    --model llama3
```

**Programmatic:**

```swift
import StreamingChatAgentAgent

let agent = try StreamingChatAgent(
    serverURL: "http://127.0.0.1:1234/v1/responses",
    modelName: "llama3"
)
let reply = try await agent.execute(goal: "Tell me a joke.")
print(reply)
```

**SwiftUI (live streaming):**

```swift
import SwiftUI
import StreamingChatAgentAgent

struct StreamingView: View {
    @State private var agent = try! StreamingChatAgent(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "llama3"
    )

    var body: some View {
        VStack {
            if agent.transcript.isStreaming {
                Text(agent.transcript.streamingText)
                ProgressView()
            }
        }
    }
}
```

## Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `serverURL` | `String` | — | Full URL of an Open Responses API endpoint |
| `modelName` | `String` | — | Model identifier |
| `apiKey` | `String?` | `nil` | Optional API key |

## How It Works

1. Validate goal non-empty; throw `emptyGoal` if empty.
2. Reset transcript, set status `.running`, append `.userMessage(goal)`.
3. Build `ResponseRequest` with `stream: true`.
4. Check `Task.isCancelled`.
5. Call `_llmClient.stream(request)` to get `AsyncThrowingStream<StreamEvent, Error>`.
6. Set `_transcript.setStreaming(true)`.
7. Iterate stream: for each `.contentPartDelta`, call `_transcript.appendDelta(chunk)` and accumulate.
8. On error: `setStreaming(false)`, set status `.error`, throw.
9. After stream closes: `setStreaming(false)`.
10. Guard accumulated text non-empty.
11. Append `.assistantMessage(accumulated)`, set `.completed`, return.

## Errors

| Case | Thrown when |
|------|------------|
| `StreamingChatAgentError.emptyGoal` | `goal` is empty |
| `StreamingChatAgentError.invalidServerURL` | URL is invalid or non-http/https |
| `StreamingChatAgentError.noResponseContent` | Stream closed with zero tokens |

## Testing

```bash
swift test --filter StreamingChatAgentTests
```

## File Structure

```
Agents/StreamingChatAgent/
├── specs/
│   ├── SPEC.md
│   └── Overview.md
├── README.md
├── Sources/
│   └── StreamingChatAgent.swift
├── CLI/
│   └── StreamingChatAgentCLI.swift
└── Tests/
    └── StreamingChatAgentTests.swift
```

## Related

- [specs/SPEC.md](specs/SPEC.md) — agent specification
- [specs/Overview.md](specs/Overview.md) — generation rules
- [LLMChat](../LLMChat/README.md) — non-streaming equivalent
- [Root README.md](../../README.md) — project overview
