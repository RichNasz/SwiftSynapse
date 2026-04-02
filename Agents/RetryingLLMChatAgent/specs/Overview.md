# Code Generation Overview: RetryingLLMChatAgent

> Instructs the code generator on what files to produce and how to assemble them from SPEC.md and shared CodeGenSpecs.

---

## Files to Generate

| File | Target | Purpose |
|------|--------|---------|
| `Sources/RetryingLLMChatAgent.swift` | `RetryingLLMChatAgentAgent` library | Main actor + error enum |
| `CLI/RetryingLLMChatAgentCLI.swift` | `retrying-llm-chat-agent` executable | ArgumentParser CLI |
| `Tests/RetryingLLMChatAgentTests.swift` | `RetryingLLMChatAgentTests` test target | Swift Testing suite |

---

## Shared Types Used

- `AgentConfiguration` — centralized config with `maxRetries` validation (1–10)
- `Agent` — from SwiftOpenResponsesDSL; handles LLM communication and transcript
- `retryWithBackoff` — **shared free function** from SwiftSynapseHarness
- `@SpecDrivenAgent` macro — generates `_status`, `_transcript`, `status`, `transcript`
- `AgentConfigurationError` — replaces per-agent `invalidServerURL` and `invalidConfiguration` cases

---

## Shared Specs to Apply

1. `Shared-Configuration.md` — `AgentConfiguration` init; `maxRetries` field is critical
2. `Shared-Retry-Strategy.md` — **this is the primary pattern** for this agent; uses shared `retryWithBackoff` free function
3. `Shared-Transcript.md` — transcript synced from Agent via `_transcript.sync(from:)`
4. `Shared-Error-Strategy.md` — error enum (top-level), status-before-throw invariant

Do NOT apply:
- `Shared-Tool-Registry.md` — no tools
- `Shared-Tool-Concurrency.md` — no tools

---

## Actor State Properties

```swift
@SpecDrivenAgent
public actor RetryingLLMChatAgent {
    private let config: AgentConfiguration
}
```

---

## Init Rules

1. Primary init takes `AgentConfiguration` (already validated, including `maxRetries` 1–10).
2. Validates client can be built via `configuration.buildLLMClient()` (fail-fast).

---

## execute() Rules

1. Guard non-empty goal → `.emptyGoal` error.
2. `_status = .running`; `_transcript.reset()`.
3. Create `Agent(client:model:)` from config.
4. Call shared `retryWithBackoff(maxAttempts: config.maxRetries)` wrapping `agent.send(goal)`, calling `agent.reset()` before each attempt.
5. Guard non-empty result → `.noResponseContent` error.
6. Sync transcript from Agent; `_status = .completed(result)`; return.

---

## CLI Rules

Uses `AgentConfiguration.fromEnvironment(overrides:)` — `--server-url` and `--model` are optional, falling back to `SWIFTSYNAPSE_*` environment variables. Includes `--max-retries` option.

---

## Test Rules

1. `retryingAgentInitThrowsOnInvalidURL` — invalid URL → `AgentConfigurationError`
2. `retryingAgentThrowsOnEmptyGoal` — empty goal → `RetryingLLMChatAgentError.emptyGoal`
3. `retryingAgentInitialStateIsIdle` — fresh instance, `.idle` status, 0 entries
4. `retryingAgentMaxRetriesValidation` — maxRetries 0 or 11 → `AgentConfigurationError.invalidMaxRetries`
5. `retryingAgentNonRetryableErrorPropagatesImmediately` — non-retryable errors skip retry, no `.reasoning` entries
