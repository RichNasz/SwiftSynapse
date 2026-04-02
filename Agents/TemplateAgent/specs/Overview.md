# CodeGen Overview: [AgentName]

> This file guides the code generator when producing Swift files for this agent. Copy and customize it for each new agent.

---

## Purpose

This `specs/` directory holds agent-specific generation specs that supplement the shared rules in `CodeGenSpecs/`. The generator reads both sets of specs and merges them when producing the output.

---

## Agent Module Structure

The generator will produce the following Swift files for this agent:

| File | Purpose |
|------|---------|
| `Sources/[AgentName].swift` | Main `@SpecDrivenAgent` actor |
| `CLI/[AgentName]CLI.swift` | ArgumentParser CLI runner |
| `Tests/[AgentName]Tests.swift` | Swift Testing suite |

Additional files as needed:
- `Sources/[AgentName]+Tools.swift` — if the agent defines tools via `AgentToolProtocol`
- `README.md` — auto-generated agent documentation (see `Agent-README-Generation.md`)

---

## Shared Types Used

- `@SpecDrivenAgent` macro — generates `_status`, `_transcript`, `status`, `transcript`, `run(goal:)`
- `AgentConfiguration` — centralized config (for LLM-calling agents)
- `retryWithBackoff` — shared retry function (for agents with LLM calls)
- `AgentToolProtocol` / `ToolRegistry` / `AgentToolLoop` — for tool-using agents
- All types available via single `import SwiftSynapseHarness`

---

## Customization Points

_Document any agent-specific overrides of shared generation rules here._

### Init Rules
[PLACEHOLDER — primary init takes `AgentConfiguration` for LLM agents, or no params for non-LLM agents]

### State Properties
[PLACEHOLDER — list any additional stored properties beyond the macro-generated defaults]

### Tool Dispatch
[PLACEHOLDER — describe tools if any; use `AgentToolLoop` for full dispatch or manual `ToolExecutor` for simple cases]

### Harness Features Used
[PLACEHOLDER — list which harness traits/features this agent uses: hooks, permissions, guardrails, recovery, streaming, etc.]

---

## CLI Rules

Uses `AgentConfiguration.fromEnvironment(overrides:)` — `--server-url` and `--model` are optional, falling back to `SWIFTSYNAPSE_*` environment variables.

---

## Test Rules

[PLACEHOLDER — list test cases derived from SPEC.md Success Criteria]
