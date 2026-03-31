# LLMChatPersonas Agent Specification

## Purpose

Extend LLMChat with an optional two-step LLM pipeline: first get a plain response to the user's goal, then (if a persona is specified) rewrite that response in the voice and style of the named persona.

---

## Configuration (constructor parameters)

| Parameter    | Type      | Default | Description                            |
|--------------|-----------|---------|----------------------------------------|
| `serverURL`  | `String`  | —       | Full URL of an Open Responses API endpoint (e.g. `http://127.0.0.1:1234/v1/responses`) |
| `modelName`  | `String`  | —       | Model identifier (e.g. `llama3`, `gpt-4o`) |
| `apiKey`     | `String?` | `nil`   | Optional API key for authentication    |

URL validation occurs at init time; throws `LLMChatPersonasError.invalidServerURL` if the string is empty, unparseable, or uses a non-http/https scheme.

---

## Input

| Parameter | Type      | Description                                                     |
|-----------|-----------|-----------------------------------------------------------------|
| `goal`    | `String`  | The prompt to send to the LLM                                   |
| `persona` | `String?` | Optional persona name for the rewrite step (e.g. `"pirate"`, `"James Kirk"`) |

---

## Tasks

1. Validate `goal` is non-empty; set status `.error(LLMChatPersonasError.emptyGoal)` and throw if empty.
2. Set status to `.running`; append a `.userMessage(goal)` transcript entry.
3. Build a `ResponseRequest` with `RequestTimeout(300)` and `ResourceTimeout(300)` in the config block, and `User(goal)` as input.
4. Call `try await _llmClient.send(request)`; extract text via `response.firstOutputText`.
5. Guard non-empty result → `.error(LLMChatPersonasError.noResponseContent)` + throw.
6. Append `.assistantMessage(initialResponse)` transcript entry.
7. **If `persona` is `nil`**: set status `.completed`; return `initialResponse`.
8. Capture `firstResponseId = firstResponse.id` from the first response.
9. Build a short persona prompt (no embedded response text):
   ```
   Rewrite your previous response in the style and voice of {persona}. Preserve all factual content but express it exactly as {persona} would speak.
   ```
10. Append `.userMessage(personaPrompt)` transcript entry.
11. Build + send a second `ResponseRequest` that includes `PreviousResponseId(firstResponseId)` in its config block to thread the conversation, with the short persona prompt as input.
12. Extract text via `response.firstOutputText`; guard non-empty → `.error(LLMChatPersonasError.noPersonaResponseContent)` + throw.
13. Append `.assistantMessage(personaResponse)`; set status `.completed`; return `personaResponse`.

---

## Errors

| Case                        | Thrown when                                        |
|-----------------------------|----------------------------------------------------|
| `emptyGoal`                 | `goal` is an empty string                          |
| `invalidServerURL`          | `serverURL` is empty, unparseable, or non-http/https |
| `noResponseContent`         | The first model reply is empty or missing          |
| `noPersonaResponseContent`  | The persona-rewrite reply is empty or missing      |

---

## Transcript shape

- **No persona**: `[.userMessage(goal), .assistantMessage(response)]` — 2 entries
- **With persona**: `[.userMessage(goal), .assistantMessage(initial), .userMessage(personaPrompt), .assistantMessage(personaFinal)]` — 4 entries

---

## Output

The final LLM reply as a `String` (persona-rewritten if a persona was provided, plain otherwise).

---

## Constraints

- Import `SwiftOpenResponsesDSL` and `SwiftSynapseMacrosClient`; no raw URLSession or OpenAI SDK.
- Endpoint must be an Open Responses API-compatible `/v1/responses` URL (not `/v1/chat/completions`).
- Request and resource timeouts must both be set to 300 seconds for both LLM calls.
- No data persistence.
- Server URL and model are init-time, not per-request.

---

## Success Criteria

- Status is `.completed` after a successful run.
- Without persona: transcript has exactly 2 entries.
- With persona: transcript has exactly 4 entries.
- Throws `LLMChatPersonasError.emptyGoal` when goal is `""`.
- Throws `LLMChatPersonasError.invalidServerURL` when the URL string is malformed or non-http/https.
- Propagates network/server errors from `LLMClient`.
