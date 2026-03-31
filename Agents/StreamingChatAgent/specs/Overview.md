# Code Generation Overview: StreamingChatAgent

> Instructs the code generator on what files to produce and how to assemble them from SPEC.md and shared CodeGenSpecs.

---

## Files to Generate

| File | Target | Purpose |
|------|--------|---------|
| `Sources/StreamingChatAgent.swift` | `StreamingChatAgentAgent` library | Main actor + error enum |
| `CLI/StreamingChatAgentCLI.swift` | `streaming-chat-agent` executable | ArgumentParser CLI |
| `Tests/StreamingChatAgentTests.swift` | `StreamingChatAgentTests` test target | Swift Testing suite |

---

## Shared Types Used

- `AgentConfiguration` — centralized config with validation
- `Agent` — from SwiftOpenResponsesDSL; `agent.stream()` returns `AsyncThrowingStream<ToolSessionEvent, Error>`
- `@SpecDrivenAgent` macro — generates `_status`, `_transcript`, `status`, `transcript`
- `AgentConfigurationError` — replaces per-agent `invalidServerURL` case

No `retryWithBackoff` — streaming calls are not retried (see SPEC.md).

---

## Shared Specs to Apply

1. `Shared-Configuration.md` — `AgentConfiguration` init pattern
2. `Shared-Transcript.md` — **streaming lifecycle** is the core pattern: `setStreaming(true/false)`, `appendDelta()`
3. `Shared-Error-Strategy.md` — error enum placement (top-level), status-before-throw invariant

Do NOT apply:
- `Shared-Retry-Strategy.md` — no retry on streaming calls
- `Shared-Tool-Registry.md` — no tools
- `Shared-Tool-Concurrency.md` — no tools

---

## Actor State Properties

```swift
@SpecDrivenAgent
public actor StreamingChatAgent {
    private let config: AgentConfiguration
}
```

---

## Init Rules

1. Primary init takes `AgentConfiguration` (already validated).
2. Validates client can be built via `configuration.buildLLMClient()` (fail-fast).
3. Legacy convenience init `(serverURL:modelName:apiKey:)` creates an `AgentConfiguration` and delegates.

---

## execute() Rules

1. Guard non-empty goal → `.emptyGoal` error.
2. `_status = .running`; `_transcript.reset()`; append `.userMessage(goal)`.
3. Create `Agent(client:model:)` from config.
4. `let stream = await agent.stream(goal)`.
5. `_transcript.setStreaming(true)`; iterate events with pattern matching on `.llm(.contentPartDelta(...))`, calling `appendDelta()`.
6. **Critical:** `setStreaming(false)` in catch block must come before `_status = .error(...)`.
7. Guard non-empty accumulated → `.noResponseContent` error.
8. Append `.assistantMessage(accumulated)`; `_status = .completed(accumulated)`; return.

---

## CLI Rules

Uses `AgentConfiguration.fromEnvironment(overrides:)` — `--server-url` and `--model` are optional, falling back to `SWIFTSYNAPSE_*` environment variables.

---

## Test Rules

1. `streamingChatAgentInitThrowsOnInvalidURL` — invalid URL → `AgentConfigurationError`
2. `streamingChatAgentThrowsOnEmptyGoal` — empty goal → `.emptyGoal` error
3. `streamingChatAgentInitialStateIsIdle` — `.idle` status, 0 entries, `isStreaming == false`, `streamingText.isEmpty`
4. `streamingChatAgentErrorPathClearsStreaming` — on connection failure, `isStreaming == false` and `streamingText.isEmpty`
