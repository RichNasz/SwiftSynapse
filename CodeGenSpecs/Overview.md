# CodeGenSpecs — Overview

> This directory contains the shared code-generation rules that apply to every agent in SwiftSynapse.

---

## Purpose

Each file in `CodeGenSpecs/` defines a **shared concern** — a cross-cutting pattern that all agents must implement in a consistent way. When generating code for any agent, the generator must incorporate all shared specs in addition to the agent's own `SPEC.md`.

---

## Shared Specs

Organized by harness trait (see `VISION.md` for trait system overview):

### Core Trait
| File | Concern |
|------|---------|
| `Shared-Observability.md` | Observable state via `@Observable` (`AgentStatus`, `ObservableTranscript`) |
| `Shared-Background-Execution.md` | `BGContinuedProcessingTask` and Swift concurrency integration |
| `Shared-LLM-Client.md` | Shared LLM client protocol and injection pattern |
| `Shared-Tool-Registry.md` | Tool definition (`@LLMTool`), `AgentToolProtocol`, `ToolRegistry` dispatch |
| `Shared-Transcript.md` | Canonical transcript model (`ObservableTranscript`, `TranscriptEntry`), streaming protocol |
| `Shared-Foundation-Models.md` | On-device inference, `AgentLLMClient` protocol, hybrid fallback |
| `Shared-Error-Strategy.md` | Error enum conventions, categorization, status-before-throw invariant |
| `Shared-Configuration.md` | `AgentConfiguration` shared value type with layered resolution |
| `Shared-Configuration-Hierarchy.md` | 7-level `ConfigurationResolver`, `ConfigurationSource` protocol, MDM support |
| `Shared-Tool-Concurrency.md` | Tool scheduling, concurrency safety, result budgeting |
| `Shared-Agent-Tool-Loop.md` | High-level `AgentToolLoop` with hooks, permissions, guardrails, recovery |
| `Shared-Streaming-Tool-Executor.md` | `StreamingToolExecutor` for concurrent tool dispatch during streaming |
| `Shared-Context-Management.md` | `ContextBudget`, `TranscriptCompressor` variants (sliding window, importance, auto, composite) |
| `Shared-System-Prompt-Builder.md` | Prioritized, cacheable `SystemPromptBuilder` |
| `Shared-Caching.md` | LRU/FIFO tool result caching with TTL |
| `Shared-Result-Truncation.md` | `ResultTruncator` for oversized tool results |
| `Shared-Graceful-Shutdown.md` | `GracefulShutdownHandler`, LIFO cleanup on termination |

### Hooks Trait
| File | Concern |
|------|---------|
| `Shared-Hook-System.md` | `AgentHook`, `AgentHookPipeline`, 16 event kinds, `HookAction`, `ClosureHook` |

### Safety Trait
| File | Concern |
|------|---------|
| `Shared-Permission-System.md` | `PermissionGate`, `PermissionPolicy`, `ToolListPolicy`, `ApprovalDelegate` |
| `Shared-Guardrails.md` | `GuardrailPipeline`, `ContentFilter`, `GuardrailPolicy`, PII/secret detection |

### Resilience Trait
| File | Concern |
|------|---------|
| `Shared-Retry-Strategy.md` | Exponential backoff retry wrapper for LLM calls |
| `Shared-Rate-Limiting.md` | `RateLimitState`, `retryWithRateLimit`, HTTP 429 cooldown tracking |
| `Shared-Recovery-Strategy.md` | `RecoveryChain`, compaction/escalation/continuation strategies |
| `Shared-Conversation-Integrity.md` | `TranscriptIntegrityCheck`, violation detection and repair |

### Observability Trait
| File | Concern |
|------|---------|
| `Shared-Telemetry.md` | `TelemetrySink`, 12 event types, privacy rules, built-in sinks |
| `Shared-Cost-Tracking.md` | `CostTracker`, `ModelPricing`, `CostTrackingTelemetrySink` |

### Persistence Trait
| File | Concern |
|------|---------|
| `Shared-Session-Resume.md` | `AgentSession` snapshot and `resume(from:)` contract |
| `Shared-Memory-System.md` | `MemoryStore`, `MemoryEntry`, cross-session agent memory |

### MultiAgent Trait
| File | Concern |
|------|---------|
| `Shared-Multi-Agent-Coordination.md` | `CoordinationRunner`, `SubagentRunner`, shared mailbox, team memory |

### MCP Trait
| File | Concern |
|------|---------|
| `Shared-MCP-Support.md` | `MCPManager`, `MCPToolBridge`, stdio/SSE/WebSocket transports |

### Plugins Trait
| File | Concern |
|------|---------|
| `Shared-Plugin-System.md` | `AgentPlugin`, `PluginManager`, `PluginContext` |

### Testing
| File | Concern |
|------|---------|
| `Shared-VCR-Testing.md` | `VCRRecording`, `VCRMode` for deterministic test replay |

### Documentation
| File | Concern |
|------|---------|
| `README-Generation.md` | Rules for generating the top-level `README.md` |
| `Agent-README-Generation.md` | Rules for generating per-agent `README.md` files |

---

## Library Hierarchy

Understanding the dependency order is required for correct import decisions:

| Package | Depends on | Purpose |
|---------|------------|---------|
| `SwiftOpenResponsesDSL` | Foundation only | LLM communication — `ResponseRequest`, `LLMClient`, `ResponseObject`, `TranscriptEntry` |
| `SwiftSynapseHarness` | `SwiftOpenResponsesDSL`, `SwiftLLMToolMacros`, `SwiftOpenSkills` | Unified agent harness — re-exports all dependencies; provides `@SpecDrivenAgent`, `AgentToolProtocol`, `ToolRegistry`, `AgentToolLoop`, hooks, permissions, recovery, streaming, MCP, guardrails, multi-agent coordination, session persistence, caching, plugins, telemetry, cost tracking, context management, `SystemPromptBuilder`, `SwiftSynapseUI` |
| `SwiftLLMToolMacros` | `SwiftOpenResponsesDSL` | Tool macros — `@LLMTool` / `@LLMToolArguments` generate `FunctionToolParam` schemas |
| `SwiftOpenSkills` | `SwiftOpenResponsesDSL` | agentskills.io standard — `SkillStore`, `SkillsAgent`, skill discovery and activation |

When generating imports for an agent file:
- Import `SwiftSynapseHarness` for every agent actor — it re-exports `SwiftOpenResponsesDSL`, `SwiftLLMToolMacros`, and `SwiftOpenSkills`, so a single import covers all types.
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
