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

- `AgentConfiguration` — centralized config with validation
- `Agent` — from SwiftOpenResponsesDSL; handles LLM communication, conversation continuity via `lastResponseId`, and transcript
- `retryWithBackoff` — shared free function for transient error retry (wraps first LLM call)
- `@SpecDrivenAgent` macro — generates `_status`, `_transcript`, `status`, `transcript`

---

## State properties

Macro-generated defaults:
- `_status: AgentStatus` (macro-managed)
- `_transcript: ObservableTranscript` (macro-managed)

Custom stored properties:
- `config: AgentConfiguration` — centralized configuration
- `lastInitialResponse: String?` — stores the first LLM response for CLI display

---

## Init rules

1. Primary init takes `AgentConfiguration` (already validated).
2. Validates client can be built via `configuration.buildLLMClient()` (fail-fast).

---

## execute() rules

1. Guard non-empty goal → `_status = .error(LLMChatPersonasError.emptyGoal)` + throw.
2. `_status = .running`; `_transcript.reset()`.
3. Create `Agent(client:model:)` from config.
4. First call with `retryWithBackoff`: `agent.send(goal)` with `agent.reset()` before each attempt.
5. Guard non-empty initial response → error + throw.
6. Store `lastInitialResponse`.
7. If `persona == nil`: sync transcript, `_status = .completed(initialResponse)`; return.
8. Second call: `agent.send(personaPrompt)` — Agent automatically chains via `lastResponseId` for conversation continuity.
9. Guard non-empty persona response → error + throw.
10. Sync transcript from Agent; `_status = .completed(personaResponse)`; return.

---

## CLI rules

Uses `AgentConfiguration.fromEnvironment(overrides:)` — `--server-url` and `--model` are optional, falling back to `SWIFTSYNAPSE_*` environment variables. Includes `--persona` option.

---

## No tool dispatch, no background execution, no structured output.
