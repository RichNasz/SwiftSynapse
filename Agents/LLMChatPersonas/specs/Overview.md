# LLMChatPersonas CodeGen Overview

## Source specs

- `Agents/LLMChatPersonas/specs/SPEC.md` — agent behavior
- `CodeGenSpecs/Overview.md` — shared generation rules
- `CodeGenSpecs/Shared-Observability.md`, `Shared-Transcript.md`, `Shared-LLM-Client.md` — shared patterns

---

## Generated files

| File                                      | Purpose                      |
|-------------------------------------------|------------------------------|
| `Sources/LLMChatPersonas.swift`           | Main actor                   |
| `CLI/LLMChatPersonasCLI.swift`            | ArgumentParser CLI runner     |
| `Tests/LLMChatPersonasTests.swift`        | Swift Testing suite           |
| `README.md`                               | Agent documentation           |

---

## State properties

Macro-generated defaults:
- `_status: AgentStatus` (macro-managed)
- `_transcript: ObservableTranscript` (macro-managed)
- `_client: LLMClient?` (macro-managed, unused — agent uses its own `_llmClient`)

Custom stored properties:
- `modelName: String` — captured at init, used in every `execute()` call
- `_llmClient: LLMClient` — initialized in `init`, holds connection to the Open Responses endpoint
- `lastInitialResponse: String?` — stores the first LLM response for CLI display

---

## Init rules

1. Validate `serverURL` is non-empty, parseable via `URL(string:)`, and uses `http` or `https` scheme; throw `LLMChatPersonasError.invalidServerURL` otherwise.
2. Store `modelName`.
3. `_llmClient = try LLMClient(baseURL: serverURL, apiKey: apiKey ?? "")`.

---

## execute() rules

1. Guard non-empty goal → `_status = .error(LLMChatPersonasError.emptyGoal)` + throw.
2. `_status = .running`; append `.userMessage(goal)`.
3. First request: `try ResponseRequest(model: modelName) { try RequestTimeout(300); try ResourceTimeout(300) } input: { User(goal) }`
4. `let response = try await _llmClient.send(request)`; `let initialResponse = response.firstOutputText ?? ""`
5. Guard non-empty → `_status = .error(LLMChatPersonasError.noResponseContent)` + throw.
6. Append `.assistantMessage(initialResponse)`.
7. If `persona == nil`: `_status = .completed(initialResponse)`; return `initialResponse`.
8. Capture `firstResponseId = firstResponse.id`.
9. Build short persona prompt: `"Rewrite your previous response in the style and voice of {persona}. Preserve all factual content but express it exactly as {persona} would speak."` — append `.userMessage(personaPrompt)`.
10. Second request: `try ResponseRequest(model: modelName) { try RequestTimeout(300); try ResourceTimeout(300); try PreviousResponseId(firstResponseId) } input: { User(personaPrompt) }` — threads conversation via API history.
11. Extract text; guard non-empty → `_status = .error(LLMChatPersonasError.noPersonaResponseContent)` + throw.
12. Append `.assistantMessage(personaResponse)`; `_status = .completed(personaResponse)`; return `personaResponse`.

---

## No tool dispatch, no background execution, no structured output.
