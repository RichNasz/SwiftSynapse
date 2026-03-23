<!-- Generated from CodeGenSpecs/Agent-README-Generation.md + Agents/LLMChat/specs/SPEC.md — Do not edit manually. -->

# LLMChat

Forward a prompt to any Open Responses API-compatible endpoint and return the model's reply.

## Overview

LLMChat is the foundational LLM agent in SwiftSynapse. It handles URL validation at init time, wraps a single user prompt in a `ResponseRequest`, sends it via `LLMClient`, and returns the reply. It demonstrates the canonical pattern for all network-backed agents: timeout configuration, transcript management via `ObservableTranscript`, and named error cases with `AgentStatus`.

**Platforms:** iOS 26+, macOS 26+, visionOS 2.4+

## Quick Start

**CLI:**

```bash
swift run llm-chat "What is the capital of France?" \
    --server-url http://127.0.0.1:1234/v1/responses \
    --model llama3
```

With an API key:

```bash
swift run llm-chat "Summarize the Observation framework." \
    --server-url https://api.openai.com/v1/responses \
    --model gpt-4o \
    --api-key sk-...
```

**Programmatic:**

```swift
import LLMChatAgent

let agent = try LLMChat(
    serverURL: "http://127.0.0.1:1234/v1/responses",
    modelName: "llama3"
)
let reply = try await agent.execute(goal: "Explain Swift actors in one paragraph.")
print(reply)
```

**SwiftUI:**

```swift
import SwiftUI
import LLMChatAgent

struct ChatView: View {
    @State private var agent = try! LLMChat(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "llama3"
    )

    var body: some View {
        VStack {
            if case .running = agent.status {
                ProgressView("Thinking...")
            }
            // agent.transcript.entries updates automatically — bind to a list
        }
    }
}
```

## Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `serverURL` | `String` | — | Full URL of an Open Responses API endpoint (e.g. `http://127.0.0.1:1234/v1/responses`) |
| `modelName` | `String` | — | Model identifier (e.g. `llama3`, `gpt-4o`) |
| `apiKey` | `String?` | `nil` | Optional API key for authenticated endpoints |

URL validation occurs at init time. Throws `LLMChatError.invalidServerURL` if the string is empty, unparseable, or uses a non-http/https scheme.

## Input

| Parameter | Type | Description |
|-----------|------|-------------|
| `goal` | `String` | The prompt to send to the LLM |

## Output

The LLM's reply as a `String`.

## How It Works

1. **Validate goal** — Guard non-empty; throw `LLMChatError.emptyGoal` and set status `.error(LLMChatError.emptyGoal)` if empty.
2. **Start running** — Set status to `.running`; append `.userMessage(goal)` to transcript.
3. **Build request** — `ResponseRequest` with `RequestTimeout(300)` and `ResourceTimeout(300)` in the config block, `User(goal)` as input.
4. **Send** — `try await _llmClient.send(request)`; extract text via `response.firstOutputText`.
5. **Guard response** — Empty or missing reply -> set status `.error(LLMChatError.noResponseContent)` + throw.
6. **Complete** — Append `.assistantMessage(responseText)` to transcript; set status `.completed(responseText)`; return text.

## Transcript Example

```
[user]      Explain Swift actors in one paragraph.
[assistant] Swift actors are reference types that protect their mutable state...
```

## Errors

| Case | Thrown when |
|------|-------------|
| `LLMChatError.emptyGoal` | `goal` is an empty string |
| `LLMChatError.invalidServerURL` | `serverURL` cannot be parsed as a valid URL |
| `LLMChatError.noResponseContent` | The model reply is empty or missing |

Network and server errors from `LLMClient` are propagated directly.

## Testing

```bash
swift test --filter LLMChatTests
```

Tests validate:
- Status is `.idle` before `execute()` is called
- Throws `LLMChatError.emptyGoal` when `goal` is `""`
- Throws `LLMChatError.invalidServerURL` for malformed or non-http/https URLs
- (Network-dependent tests require a live endpoint and are not included in the unit suite)

## Constraints

- Imports `SwiftSynapseMacrosClient`; no raw `URLSession` or OpenAI SDK
- Endpoint must be an Open Responses API-compatible `/v1/responses` URL (not `/v1/chat/completions`)
- Both `RequestTimeout` and `ResourceTimeout` are set to 300 seconds to accommodate slow local LLM inference
- No data persistence; server URL and model are init-time, not per-request

## File Structure

```
Agents/LLMChat/
├── specs/
│   ├── SPEC.md
│   └── Overview.md
├── README.md
├── Sources/
│   └── LLMChat.swift
├── CLI/
│   └── LLMChatCLI.swift
└── Tests/
    └── LLMChatTests.swift
```

## Related

- [specs/SPEC.md](specs/SPEC.md) — agent specification
- [specs/Overview.md](specs/Overview.md) — generation rules
- [LLMChatPersonas](../LLMChatPersonas/README.md) — extends LLMChat with optional persona rewriting
- [Root README.md](../../README.md) — project overview
