# LLMChatPersonas CodeGen Overview

## Source specs

- `Agents/LLMChatPersonas/specs/SPEC.md` — agent behavior
- `CodeGenSpecs/Overview.md` — shared generation rules
- `CodeGenSpecs/Shared-Configuration.md`, `Shared-Retry-Strategy.md`, `Shared-Transcript.md` — shared patterns

---

## Generated files

| File                                      | Purpose                      |
|-------------------------------------------|------------------------------|
| `Sources/LLMChatPersonas.swift`           | Main actor                   |
| `CLI/LLMChatPersonasCLI.swift`            | ArgumentParser CLI runner     |
| `Tests/LLMChatPersonasTests.swift`        | Swift Testing suite           |

---

## Shared Types Used

- `AgentConfiguration` — centralized config with validation; replaces inline URL validation
- `retryWithBackoff` — shared free function for transient error retry (wraps both LLM calls)
- `@SpecDrivenAgent` macro — generates `_status`, `_transcript`, `status`, `transcript`, `run(goal:)`
- `LLMClient` — via `config.buildLLMClient()`

---

## State properties

Macro-generated defaults:
- `_status: AgentStatus` (macro-managed)
- `_transcript: ObservableTranscript` (macro-managed)
- `_client: LLMClient?` (macro-managed, unused — agent uses its own `_llmClient`)

Custom stored properties:
- `config: AgentConfiguration` — centralized configuration
- `_llmClient: LLMClient` — built from `config.buildLLMClient()`
- `lastInitialResponse: String?` — stores the first LLM response for CLI display

---

## Init rules

1. Primary init takes `AgentConfiguration` (already validated).
2. `_llmClient = try configuration.buildLLMClient()`.
3. Legacy convenience init `(serverURL:modelName:apiKey:)` creates an `AgentConfiguration` and delegates.

---

## execute() rules

1. Guard non-empty goal → `_status = .error(LLMChatPersonasError.emptyGoal)` + throw.
2. `_status = .running`; `_transcript.reset()`; append `.userMessage(goal)`.
3. First request with `retryWithBackoff`: `ResponseRequest(model: config.modelName)` with timeouts from config.
4. Guard non-empty initial response → error + throw.
5. Store `lastInitialResponse`; append `.assistantMessage(initialResponse)`.
6. If `persona == nil`: `_status = .completed(initialResponse)`; return.
7. Build persona prompt; append `.userMessage(personaPrompt)`.
8. Second request with `retryWithBackoff` using `PreviousResponseId(firstResponseId)` for conversation threading.
9. Guard non-empty persona response → error + throw.
10. Append `.assistantMessage(personaResponse)`; `_status = .completed(personaResponse)`; return.

---

## CLI rules

Uses `AgentConfiguration.fromEnvironment(overrides:)` — `--server-url` and `--model` are optional, falling back to `SWIFTSYNAPSE_*` environment variables. Includes `--persona` option.

---

## No tool dispatch, no background execution, no structured output.
