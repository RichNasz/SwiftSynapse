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

No additional state beyond the macro-generated defaults:
- `_status: AgentStatus` (macro-managed)
- `_transcript: [TranscriptEntry]` (macro-managed)

Custom stored property:
- `modelName: String` — captured at init, used in every `run()` call
- `client: LLMClient` — initialized in `init`, holds connection to the Open Responses endpoint

---

## Init rules

1. Validate `serverURL` with `URL(string:)`; throw `LLMChatError.invalidServerURL` if nil.
2. Store `modelName`.
3. `client = try LLMClient(baseURL: serverURL, apiKey: apiKey ?? "")`.

---

## run() rules

1. Guard non-empty goal → `.failed` + throw `LLMChatError.emptyGoal`.
2. `_status = .running`; append `.user` transcript entry.
3. `let request = try ResponseRequest(model: modelName) { try RequestTimeout(300); try ResourceTimeout(300) } input: { User(goal) }`
4. `let response = try await client.send(request)`
5. `let responseText = response.firstOutputText ?? ""`
6. Guard non-empty → `.failed` + throw `LLMChatError.noResponseContent`.
7. Append `.assistant` transcript entry; `_status = .completed`; return text.

---

## No tool dispatch, no background execution, no structured output.
