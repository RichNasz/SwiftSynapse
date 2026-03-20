# CodeGenSpecs — Overview

> This directory contains the shared code-generation rules that apply to every agent in SwiftSynapse.

---

## Purpose

Each file in `CodeGenSpecs/` defines a **shared concern** — a cross-cutting pattern that all agents must implement in a consistent way. When generating code for any agent, the generator must incorporate all shared specs in addition to the agent's own `SPEC.md`.

---

## Shared Specs

| File | Concern |
|------|---------|
| `Shared-Observability.md` | How agent state and transcript are exposed via `@Observable` |
| `Shared-Background-Execution.md` | How agents integrate with `BGContinuedProcessingTask` and Swift concurrency |
| `Shared-LLM-Client.md` | The shared LLM client protocol and injection pattern |
| `Shared-Tool-Registry.md` | How tools are registered, discovered, and dispatched |
| `Shared-Transcript.md` | The canonical transcript model and streaming delta protocol |
| `README-Generation.md` | Rules for generating the top-level `README.md` |
| `Agent-README-Generation.md` | Rules for generating per-agent `README.md` files |

---

## Library Hierarchy

Understanding the dependency order is required for correct import decisions:

| Package | Depends on | Purpose |
|---------|------------|---------|
| `SwiftOpenResponsesDSL` | Foundation only | LLM communication — `ResponseRequest`, `LLMClient`, `ResponseObject` |
| `SwiftSynapseMacros` | `SwiftOpenResponsesDSL` | Agent creation macros — `@SpecDrivenAgent` synthesizes agent boilerplate |
| `SwiftLLMToolMacros` | `SwiftOpenResponsesDSL` | Tool macros — `@LLMTool` / `@LLMToolArguments` generate `FunctionToolParam` schemas |

When generating imports for an agent file:
- Always include `SwiftOpenResponsesDSL` if the agent sends any LLM request.
- Include `SwiftSynapseMacros` for every agent actor (provides the `@SpecDrivenAgent` macro and macro-generated members).
- Include `SwiftLLMToolMacros` only in files that define tool structs.

---

## How Generation Works

1. An agent author writes or updates `Agents/<AgentName>/SPEC.md`.
2. The generator reads the agent spec **and** all files in `CodeGenSpecs/`.
3. Generated `.swift` files are written to `Agents/<AgentName>/Generated/`.
4. The generated files are never edited manually. To change behavior, update the spec and regenerate.

---

## Conventions

- All generated types use `@Observable` for state exposure.
- All async work uses structured concurrency (`async`/`await`, `TaskGroup`, `AsyncStream`).
- Tool schemas are generated from `@LLMTool` macros (SwiftLLMToolMacros).
- Responses are constructed via `SwiftOpenResponsesDSL`.
- No `import` of third-party AI frameworks is allowed in generated files.
