# Agent Spec: RetryingLLMChatAgent

> Reference implementation for retry behavior. Demonstrates `retryWithBackoff`, retryable vs. terminal error classification, and retry transcript annotations.

---

## Goal

Behave identically to `LLMChat` — forward a prompt to the LLM and return the response — but wrap every `_llmClient.send()` call in exponential-backoff retry. Retry attempts are annotated in the transcript so callers can observe retry activity.

---

## Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `configuration` | `AgentConfiguration` | — | Server URL, model, API key, timeout, `maxRetries` (default 3) |

The `maxRetries` field from `AgentConfiguration` directly controls how many times each LLM call is retried before failing.

---

## Input

| Parameter | Type | Description |
|-----------|------|-------------|
| `goal` | `String` | The user's prompt |

---

## Tools

None. Retry behavior is demonstrated on bare LLM calls to keep the spec unambiguous.

---

## Tasks (execute steps)

1. Validate `goal` is non-empty. Set `_status = .error(RetryingLLMChatAgentError.emptyGoal)` and throw if empty.
2. Reset `_agentContext`. Set `_status = .running`. Emit `agentStarted`. Append `.userMessage(goal)`.
3. Build `ResponseRequest`.
4. Check `Task.isCancelled`.
5. Call `retryWithBackoff(maxAttempts: maxRetries, onRetry: annotateRetry)` wrapping `_llmClient.send(request)`.
   - The `annotateRetry` callback appends `.reasoning("Retrying LLM call (attempt \(attempt) of \(maxRetries))…")` to the transcript before the retry executes.
   - Retryable errors: `URLError.timedOut`, `URLError.networkConnectionLost`, `URLError.notConnectedToInternet`, HTTP 429, HTTP 503.
   - On exhaustion: set `_status = .error(e)`, emit `agentFailed`, throw.
6. Extract `firstOutputText`. Guard non-empty — throw `RetryingLLMChatAgentError.noResponseContent` if empty.
7. Append `.assistantMessage`. Set `_status = .completed`. Emit `agentCompleted`. Return.

---

## Errors

```swift
public enum RetryingLLMChatAgentError: Error, Sendable {
    case emptyGoal           // terminal — never retried
    case noResponseContent   // terminal — never retried
}
```

Network and transport errors are not cases in this enum — they propagate from `_llmClient.send()` after all retries are exhausted.

---

## Output

The LLM's response text as a `String`.

---

## Transcript Shape

No retries:
```
[0] .userMessage("Hello, world.")
[1] .assistantMessage("Hello! How can I help you today?")
```

With one retry:
```
[0] .userMessage("Hello, world.")
[1] .reasoning("Retrying LLM call (attempt 2 of 3)…")
[2] .assistantMessage("Hello! How can I help you today?")
```

With two retries (failed on first two attempts, succeeded on third):
```
[0] .userMessage("Hello, world.")
[1] .reasoning("Retrying LLM call (attempt 2 of 3)…")
[2] .reasoning("Retrying LLM call (attempt 3 of 3)…")
[3] .assistantMessage("Hello! How can I help you today?")
```

---

## Constraints

- Open Responses API only.
- No tools, no streaming, no background execution, no session resume.
- Retry annotations use `.reasoning` entries (not `.error`) — retries are normal operation, not failures.
- The retry annotation content is fixed — no error messages or user content.
- `maxRetries` must be in `1...10` (enforced by `AgentConfiguration` validation).

---

## Success Criteria

1. Empty goal throws `RetryingLLMChatAgentError.emptyGoal` and status is `.error`.
2. A successful response (no retries) produces a 2-entry transcript and `.completed` status.
3. When the injected mock client fails once then succeeds, the transcript has 3 entries: `.userMessage`, `.reasoning("Retrying LLM call (attempt 2 of 3)…")`, `.assistantMessage`.
4. When the injected mock client fails `maxRetries` times, the error propagates and status is `.error`.
5. `emptyGoal` error is not retried — the retry wrapper is never invoked.

---

## Platforms

iOS 26+, macOS 26+, visionOS 2.4+. Swift 6.2+ strict concurrency.
