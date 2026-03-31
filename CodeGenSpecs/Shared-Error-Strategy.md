# Shared Spec: Error Strategy

> Defines the error model that all SwiftSynapse agents must follow to ensure consistent handling, safe telemetry, and correct state transitions.

---

## Summary

Every agent defines a typed error enum that precisely describes what can go wrong. Errors are categorized as retryable or terminal, always precede a `_status` mutation, and never expose user content in logged contexts.

---

## Error Enum Convention

Every agent that can fail must define:

```swift
public enum <AgentName>Error: Error, Sendable {
    // Input validation errors (always terminal)
    case emptyGoal
    case invalidConfiguration

    // LLM errors (may be retryable at the transport layer)
    case noResponseContent

    // Tool-using agents only
    case toolCallFailed(String)   // carries tool name
    case unknownTool(String)      // carries tool name received from LLM
}
```

Rules:
- The enum is always `public` and `Sendable`.
- For agents that do not call an LLM (e.g., `SimpleEcho`), only include the cases that apply.
- For tool-using agents, always include `toolCallFailed` and `unknownTool`.
- Do not add cases for errors that originate outside the agent (e.g., `URLError`, `DecodingError`) — let those propagate as-is.
- Tool-using agents must include `toolLoopExceeded` (see `Shared-Tool-Concurrency.md`). This case is terminal and guards against infinite tool dispatch loops.

---

## Error Categorization

Each error case is categorized as **terminal** or **retryable**:

| Case | Category | Reason |
|------|----------|--------|
| `emptyGoal` | terminal | Caller error — retry will produce the same result |
| `invalidConfiguration` | terminal | Agent cannot proceed at all |
| `noResponseContent` | terminal | LLM returned a valid but empty response; retry rarely helps |
| `toolCallFailed` | terminal | Tool logic failed; retry depends on tool semantics |
| `unknownTool` | terminal | LLM hallucinated a tool name |
| Network / transport errors | retryable | Checked by the retry layer, not by the agent directly |

Agents do **not** implement retry logic themselves. Instead, they throw and let `Shared-Retry-Strategy` wrap the retryable call site. Only transport-layer errors (from `LLMClient.send()`) are retried.

---

## Status-Before-Throw Invariant

Before throwing any error, the agent must set `_status = .error(e)`:

```swift
// CORRECT
guard !goal.isEmpty else {
    let e = MyAgentError.emptyGoal
    _status = .error(e)
    throw e
}

// WRONG — status is stale after the throw
guard !goal.isEmpty else {
    throw MyAgentError.emptyGoal
}
```

This is an absolute invariant. Code generation must always produce the status mutation before the throw. There are no exceptions.

---

## Network Error Passthrough

Errors from `LLMClient.send()` are never wrapped in an agent-specific error type. They propagate directly to the caller:

```swift
// CORRECT — let the network error propagate
let response = try await _llmClient.send(request)

// WRONG — wrapping destroys the original error type and prevents retry classification
let response: Response
do {
    response = try await _llmClient.send(request)
} catch {
    throw MyAgentError.networkFailure(error)   // do NOT do this
}
```

The one exception: if the agent sets `_status = .error(networkError)` before the error propagates, that is required. Set status, then let the error propagate:

```swift
do {
    response = try await _llmClient.send(request)
} catch {
    _status = .error(error)
    throw error
}
```

---

## Telemetry-Safe Error Logging

Errors from agent execution may be logged for diagnostics. Agents must never include user-supplied content (goal strings, LLM responses, tool arguments) in logged error messages. Only the error **type** is safe to log.

**Safe to log:**
```swift
// Log the type name only
logger.error("Agent failed: \(type(of: error))")
```

**Never log:**
```swift
// WRONG — goal may contain PII
logger.error("Agent failed for goal '\(goal)': \(error)")
```

The `toolCallFailed(String)` and `unknownTool(String)` associated values carry tool **names** (not user content) and are safe to log.

---

## Error Enum Placement

- For agents where the error enum has 1–3 cases: define it as a **nested enum** inside the actor.
- For agents where the error enum has 4+ cases or is shared across files: define it as a **top-level public enum** in the same source file, above the actor declaration.

Currently, `SimpleEchoError` is nested and `LLMChatError` is top-level. Going forward: all agents with LLM errors use top-level placement for consistency.
