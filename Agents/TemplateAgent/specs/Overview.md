# CodeGen Overview: [AgentName]

> This file guides the code generator when producing Swift files for this agent. Copy and customize it for each new agent.

---

## Purpose

This `specs/` directory holds agent-specific generation specs that supplement the shared rules in `CodeGenSpecs/`. The generator reads both sets of specs and merges them when producing the `Generated/` output.

---

## Agent Module Structure

The generator will produce the following Swift files for this agent:

| File | Purpose |
|------|---------|
| `[AgentName].swift` | Main `@SpecDrivenAgent` actor |
| `[AgentName]+Tools.swift` | `@LLMTool`-annotated tool functions |
| `[AgentName]+Background.swift` | `BGContinuedProcessingTask` integration |
| `[AgentName]+Transcript.swift` | Agent-specific transcript extensions (if any) |
| `README.md` | Auto-generated agent documentation |

---

## Customization Points

_Document any agent-specific overrides of shared generation rules here._

### State Properties
[PLACEHOLDER — list any additional `@Observable` properties beyond the shared defaults]

### Tool Dispatch
[PLACEHOLDER — describe any custom tool routing logic beyond the shared `ToolRegistry`]

### Background Checkpoint Format
[PLACEHOLDER — describe the checkpoint data structure for this agent]

### SwiftUI Integration Notes
[PLACEHOLDER — any notes for the view layer that consumes this agent]

---

## Generation Command

```
# To regenerate this agent's Swift files:
# swift run SwiftSynapseCodeGen --agent [AgentName]
```

_(Command format subject to change as the tooling matures.)_
