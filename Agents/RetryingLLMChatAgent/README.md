<!-- Generated from CodeGenSpecs/Agent-README-Generation.md + Agents/RetryingLLMChatAgent/specs/SPEC.md — Do not edit manually. -->

# RetryingLLMChatAgent

Forward a prompt to any Open Responses API-compatible endpoint with automatic exponential-backoff retry on transient failures.

## Overview

RetryingLLMChatAgent behaves identically to LLMChat but wraps every `_llmClient.send()` call in exponential-backoff retry. Retry attempts are annotated in the transcript so callers can observe retry activity. This is the reference implementation for retry behavior in SwiftSynapse.

**Platforms:** iOS 26+, macOS 26+, visionOS 2.4+

## Quick Start

**CLI:**

```bash
swift run retrying-llm-chat-agent "Hello, world." \
    --server-url http://127.0.0.1:1234/v1/responses \
    --model llama3
```

With custom retry count:

```bash
swift run retrying-llm-chat-agent "Hello" \
    --server-url http://127.0.0.1:1234/v1/responses \
    --model llama3 \
    --max-retries 5
```

**Programmatic:**

```swift
import RetryingLLMChatAgentAgent

let agent = try RetryingLLMChatAgent(
    serverURL: "http://127.0.0.1:1234/v1/responses",
    modelName: "llama3",
    maxRetries: 3
)
let reply = try await agent.execute(goal: "Explain retry strategies.")
print(reply)
```

## Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `serverURL` | `String` | — | Full URL of an Open Responses API endpoint |
| `modelName` | `String` | — | Model identifier (e.g. `llama3`, `gpt-4o`) |
| `apiKey` | `String?` | `nil` | Optional API key |
| `maxRetries` | `Int` | `3` | Maximum retry attempts (1–10) |

## How It Works

1. Validate goal non-empty; throw `emptyGoal` if empty.
2. Reset transcript, set status `.running`, append `.userMessage(goal)`.
3. Build `ResponseRequest` with 300s timeouts.
4. Check `Task.isCancelled`.
5. Call `retryWithBackoff(maxAttempts: maxRetries)` wrapping `_llmClient.send(request)`.
   - On retry: append `.reasoning("Retrying LLM call (attempt N of M)…")` to transcript.
   - Retryable errors: `URLError.timedOut`, `.networkConnectionLost`, `.notConnectedToInternet`.
   - On exhaustion: set status `.error`, throw.
6. Guard response text non-empty.
7. Append `.assistantMessage`, set `.completed`, return.

## Transcript Example

No retries:
```
[user]      Hello, world.
[assistant] Hello! How can I help you today?
```

With one retry:
```
[user]      Hello, world.
[reasoning] Retrying LLM call (attempt 2 of 3)…
[assistant] Hello! How can I help you today?
```

## Errors

| Case | Thrown when |
|------|------------|
| `RetryingLLMChatAgentError.emptyGoal` | `goal` is empty |
| `RetryingLLMChatAgentError.invalidServerURL` | URL is invalid or non-http/https |
| `RetryingLLMChatAgentError.noResponseContent` | Model reply is empty |

Network errors propagate after all retries are exhausted.

## Testing

```bash
swift test --filter RetryingLLMChatAgentTests
```

## File Structure

```
Agents/RetryingLLMChatAgent/
├── specs/
│   ├── SPEC.md
│   └── Overview.md
├── README.md
├── Sources/
│   └── RetryingLLMChatAgent.swift
├── CLI/
│   └── RetryingLLMChatAgentCLI.swift
└── Tests/
    └── RetryingLLMChatAgentTests.swift
```

## Related

- [specs/SPEC.md](specs/SPEC.md) — agent specification
- [specs/Overview.md](specs/Overview.md) — generation rules
- [LLMChat](../LLMChat/README.md) — base agent without retry
- [Root README.md](../../README.md) — project overview
