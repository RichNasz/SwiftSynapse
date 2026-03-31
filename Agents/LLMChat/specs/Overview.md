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

- `AgentConfiguration` — centralized config with validation; replaces inline URL validation
- `retryWithBackoff` — shared free function for transient error retry
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

---

## Init rules

1. Primary init takes `AgentConfiguration` (already validated).
2. `_llmClient = try configuration.buildLLMClient()`.
3. Legacy convenience init `(serverURL:modelName:apiKey:)` creates an `AgentConfiguration` and delegates.

---

## execute() rules

1. Guard non-empty goal → `.error(LLMChatError.emptyGoal)` + throw.
2. `_status = .running`; `_transcript.reset()`; append `.userMessage(goal)`.
3. Build `ResponseRequest` with `config.modelName` and `TimeInterval(config.timeoutSeconds)`.
4. Call `retryWithBackoff(maxAttempts: config.maxRetries)` wrapping `_llmClient.send(request)`.
5. Guard non-empty response → `.error(LLMChatError.noResponseContent)` + throw.
6. Append `.assistantMessage(responseText)`; `_status = .completed(responseText)`; return text.

---

## CLI rules

Uses `AgentConfiguration.fromEnvironment(overrides:)` — `--server-url` and `--model` are optional, falling back to `SWIFTSYNAPSE_*` environment variables.

---

## No tool dispatch, no background execution, no structured output.
