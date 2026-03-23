# LLMChat CodeGen Overview

## Source specs

- `Agents/LLMChat/specs/SPEC.md` — agent behavior
- `CodeGenSpecs/Overview.md` — shared generation rules
- `CodeGenSpecs/Shared-Observability.md`, `Shared-Transcript.md`, `Shared-LLM-Client.md` — shared patterns

---

## Generated files

| File                            | Purpose                     |
|---------------------------------|-----------------------------|
| `Sources/LLMChat.swift`         | Main actor                  |
| `CLI/LLMChatCLI.swift`          | ArgumentParser CLI runner    |
| `Tests/LLMChatTests.swift`      | Swift Testing suite          |
| `README.md`                     | Agent documentation          |

---

## State properties

Macro-generated defaults:
- `_status: AgentStatus` (macro-managed)
- `_transcript: ObservableTranscript` (macro-managed)
- `_client: LLMClient?` (macro-managed, unused — agent uses its own `_llmClient`)

Custom stored properties:
- `modelName: String` — captured at init, used in every `execute()` call
- `_llmClient: LLMClient` — initialized in `init`, holds connection to the Open Responses endpoint

---

## Init rules

1. Validate `serverURL` with `URL(string:)`; throw `LLMChatError.invalidServerURL` if nil or non-http/https.
2. Store `modelName`.
3. `_llmClient = try LLMClient(baseURL: serverURL, apiKey: apiKey ?? "")`.

---

## execute() rules

1. Guard non-empty goal → `.error(LLMChatError.emptyGoal)` + throw.
2. `_status = .running`; append `.userMessage(goal)`.
3. `let request = try ResponseRequest(model: modelName) { try RequestTimeout(300); try ResourceTimeout(300) } input: { User(goal) }`
4. `let response = try await _llmClient.send(request)`
5. `let responseText = response.firstOutputText ?? ""`
6. Guard non-empty → `.error(LLMChatError.noResponseContent)` + throw.
7. Append `.assistantMessage(responseText)`; `_status = .completed(responseText)`; return text.

---

## No tool dispatch, no background execution, no structured output.
