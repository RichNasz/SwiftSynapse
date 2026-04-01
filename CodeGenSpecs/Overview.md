# CodeGenSpecs — Overview

> This directory contains the shared code-generation rules that apply to every agent in SwiftSynapse.

---

## Purpose

Each file in `CodeGenSpecs/` defines a **shared concern** — a cross-cutting pattern that all agents must implement in a consistent way. When generating code for any agent, the generator must incorporate all shared specs in addition to the agent's own `SPEC.md`.

---

## Shared Specs

| File | Concern |
|------|---------|
| `Shared-Observability.md` | How agent state and transcript are exposed via `@Observable` (`AgentStatus`, `ObservableTranscript`) |
| `Shared-Background-Execution.md` | How agents integrate with `BGContinuedProcessingTask` and Swift concurrency |
| `Shared-LLM-Client.md` | The shared LLM client protocol and injection pattern |
| `Shared-Tool-Registry.md` | How tools are registered, discovered, and dispatched |
| `Shared-Transcript.md` | The canonical transcript model (`ObservableTranscript`, `TranscriptEntry`) and streaming protocol |
| `Shared-Foundation-Models.md` | On-device inference via Foundation Models framework, `AgentLLMClient` protocol, hybrid fallback |
| `Shared-Error-Strategy.md` | Error enum conventions, categorization, status-before-throw invariant |
| `Shared-Retry-Strategy.md` | Exponential backoff retry wrapper for LLM calls |
| `Shared-Configuration.md` | `AgentConfiguration` shared value type with layered resolution |
| `Shared-Tool-Concurrency.md` | Tool scheduling, concurrency safety, result budgeting |
| `Shared-Telemetry.md` | Opt-in telemetry events and `TelemetrySink` protocol |
| `Shared-Session-Resume.md` | `AgentSession` snapshot and `resume(from:)` contract |
| `README-Generation.md` | Rules for generating the top-level `README.md` |
| `Agent-README-Generation.md` | Rules for generating per-agent `README.md` files |

---

## Library Hierarchy

Understanding the dependency order is required for correct import decisions:

| Package | Depends on | Purpose |
|---------|------------|---------|
| `SwiftOpenResponsesDSL` | Foundation only | LLM communication — `ResponseRequest`, `LLMClient`, `ResponseObject`, `TranscriptEntry` |
| `SwiftSynapseMacros` | `SwiftOpenResponsesDSL`, `SwiftLLMToolMacros`, `SwiftOpenSkills` | Agent harness + macros + SwiftUI — `@SpecDrivenAgent`, `AgentToolProtocol`, `ToolRegistry`, `AgentToolLoop`, hooks, permissions, recovery, streaming, MCP, guardrails, multi-agent coordination, session persistence, caching, plugins, telemetry, `SwiftSynapseUI` |
| `SwiftLLMToolMacros` | `SwiftOpenResponsesDSL` | Tool macros — `@LLMTool` / `@LLMToolArguments` generate `FunctionToolParam` schemas |
| `SwiftOpenSkills` | `SwiftOpenResponsesDSL` | agentskills.io standard — `SkillStore`, `SkillsAgent`, skill discovery and activation |

When generating imports for an agent file:
- Import `SwiftSynapseMacrosClient` for every agent actor — it re-exports both `SwiftOpenResponsesDSL` and `SwiftLLMToolMacros`, so a single import covers all types.
- Import `Foundation` explicitly only if the agent uses `URL` or other Foundation types directly.

---

## `@SpecDrivenAgent` Macro — Generated Members

The macro generates these members on every agent actor:

| Member | Type | Purpose |
|--------|------|---------|
| `_status` | `AgentStatus` | Private backing for lifecycle state (`.idle`, `.running`, `.paused`, `.error(Error)`, `.completed(Any)`) |
| `_transcript` | `ObservableTranscript` | Private backing for conversation history |
| `_client` | `LLMClient?` | Private optional LLM client |
| `status` | `AgentStatus` | Public read-only accessor |
| `transcript` | `ObservableTranscript` | Public read-only accessor |
| `client` | `LLMClient` | Public accessor (fatalError if not configured) |
| `configure(client:)` | method | Inject an LLM client |
| `_telemetrySink` | `(any TelemetrySink)?` | Optional weak telemetry sink (see `Shared-Telemetry.md`) |
| `configure(telemetry:)` | method | Inject a telemetry sink |
| `run(goal:)` | `async throws` | Generic runtime loop via `AgentRuntime` |

Agent-specific logic should be placed in a custom `execute(goal:)` method (or similar), which accesses `_status` and `_transcript` directly.

---

## How Generation Works

1. An agent author writes or updates `Agents/<AgentName>/specs/SPEC.md`.
2. The generator reads the agent spec **and** all files in `CodeGenSpecs/`.
3. Generated `.swift` files are written to `Agents/<AgentName>/Sources/`, `CLI/`, and `Tests/`.
4. The generated files are never edited manually. To change behavior, update the spec and regenerate.

---

## Conventions

- All agent actors use `@SpecDrivenAgent` for observable state (`AgentStatus`, `ObservableTranscript`).
- All async work uses structured concurrency (`async`/`await`, `TaskGroup`, `AsyncStream`).
- Tool schemas are generated from `@LLMTool` macros (SwiftLLMToolMacros).
- Responses are constructed via `SwiftOpenResponsesDSL`.
- No `import` of third-party AI frameworks is allowed in generated files.
- `import FoundationModels` is allowed inside `#if canImport(FoundationModels)` guards for on-device inference (see `Shared-Foundation-Models.md`).
