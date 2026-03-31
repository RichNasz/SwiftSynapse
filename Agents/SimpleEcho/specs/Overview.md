# CodeGen Overview: SimpleEcho

> Guides the code generator when producing Swift files for this agent.

---

## Purpose

This `specs/` directory holds agent-specific generation specs that supplement the shared rules in `CodeGenSpecs/`. The generator reads both sets of specs and merges them when producing the output.

---

## Agent Module Structure

| File | Purpose |
|------|---------|
| `SimpleEcho.swift` | Main `@SpecDrivenAgent` actor with `execute(goal:)` |
| `SimpleEchoCLI.swift` | CLI runner using swift-argument-parser |
| `SimpleEchoTests.swift` | Swift Testing suite |

No additional files are needed — this agent has no tools, no background execution, and no transcript extensions.

---

## Shared Types Used

- `@SpecDrivenAgent` macro — generates `_status`, `_transcript`, `status`, `transcript`
- `AgentStatus` — `.idle`, `.running`, `.error(Error)`, `.completed(String)`
- `ObservableTranscript` — `@Observable` class with `entries`, `append()`, `reset()`

No `AgentConfiguration`, `LLMClient`, or `retryWithBackoff` — this agent never calls an LLM.

---

## State Properties

Uses macro-generated defaults only. No additional stored properties.

---

## execute() Rules

1. Guard non-empty goal → `.error(SimpleEchoError.emptyGoal)` + throw.
2. `_status = .running`; `_transcript.reset()`; append `.userMessage(goal)`.
3. Build echo string; append `.assistantMessage(echoed)`.
4. `_status = .completed(echoed)`; return text.

---

## CLI Rules

No LLM configuration needed. Goal is a positional argument.

---

## Test Rules

1. `simpleEchoProducesExpectedTranscript` — execute with "test", verify 2 transcript entries and correct content.
2. `simpleEchoThrowsOnEmptyGoal` — empty goal → error, status `.error`.
