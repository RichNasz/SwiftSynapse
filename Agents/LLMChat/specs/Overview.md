# LLMChat CodeGen Overview

## Source specs

- `Agents/LLMChat/specs/SPEC.md` — agent behavior
- `CodeGenSpecs/Overview.md` — shared generation rules
- `CodeGenSpecs/Shared-Configuration.md`, `Shared-Retry-Strategy.md`, `Shared-Transcript.md` — shared patterns

---

## Generated files

| File                            | Purpose                     |
|---------------------------------|-----------------------------|
| `Sources/LLMChat.swift`         | Main actor                  |
| `CLI/LLMChatCLI.swift`          | ArgumentParser CLI runner    |
| `Tests/LLMChatTests.swift`      | Swift Testing suite          |

---

## Shared Types Used

- `AgentConfiguration` — centralized config with validation
- `Agent` — from SwiftOpenResponsesDSL; handles LLM communication and transcript
- `retryWithBackoff` — shared free function for transient error retry
- `@SpecDrivenAgent` macro — generates `_status`, `_transcript`, `status`, `transcript`

---

## State properties

Macro-generated defaults:
- `_status: AgentStatus` (macro-managed)
- `_transcript: ObservableTranscript` (macro-managed)

Custom stored properties:
- `config: AgentConfiguration` — centralized configuration

---

## Init rules

1. Primary init takes `AgentConfiguration` (already validated).
2. Validates client can be built via `configuration.buildLLMClient()` (fail-fast).
3. Legacy convenience init `(serverURL:modelName:apiKey:)` creates an `AgentConfiguration` and delegates.

---

## execute() rules

1. Guard non-empty goal → `.error(LLMChatError.emptyGoal)` + throw.
2. `_status = .running`; `_transcript.reset()`.
3. Create `Agent(client:model:)` from config.
4. Call `retryWithBackoff(maxAttempts: config.maxRetries)` wrapping `agent.send(goal)`, calling `agent.reset()` before each attempt.
5. Guard non-empty result → `.error(LLMChatError.noResponseContent)` + throw.
6. Sync transcript from Agent via `_transcript.sync(from: agent.transcript)`.
7. `_status = .completed(result)`; return text.

---

## CLI rules

Uses `AgentConfiguration.fromEnvironment(overrides:)` — `--server-url` and `--model` are optional, falling back to `SWIFTSYNAPSE_*` environment variables.

---

## No tool dispatch, no background execution, no structured output.
