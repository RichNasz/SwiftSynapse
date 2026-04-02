# SwiftSynapse Project Vision

## Overview
SwiftSynapse is an open-source showcase and foundational framework for building **smart, autonomous AI agents** natively in pure Swift for Apple platforms.

The project demonstrates production-grade agentic patterns using:
- A unified agent harness (SwiftSynapseHarness) with modular Package Traits (SE-0450)
- Declarative macros (`@SpecDrivenAgent`, `@LLMTool`, `@LLMToolArguments`)
- Type-safe LLM interactions (via SwiftOpenResponsesDSL)
- Compile-time tool definitions (via SwiftLLMToolMacros)

Agents are designed to be:
- Observable (real-time reasoning, tool calls, and transcript visible in SwiftUI)
- Background-capable (foreground start → continued execution via BGContinuedProcessingTask)
- On-device first (Foundation Models framework priority) with hybrid cloud fallback where on-device is unavailable
- Fully spec-driven (AI-generated code only, no human hand-written implementation)

Target platforms: iOS 26+, macOS 26+, visionOS 2.4+ (where Apple Intelligence and Foundation Models framework are supported).

## Core Goals
- Enable Swift developers to integrate powerful autonomous agents into their apps with minimal boilerplate.
- Provide runnable, high-quality agent examples (code review, performance optimization, task planning, research, etc.).
- Showcase the full power of Swift-native macros for agent orchestration, observability, and tool calling.
- Prove that agentic AI can be elegant, type-safe, and performant in the Apple ecosystem — prioritizing on-device privacy and speed.

## Key Principles & Non-Negotiables
- **AI-first, AI-always code generation**  
  All implementation code (Sources/, Tests/), README.md, documentation, and examples are generated exclusively from specifications via Claude Code (or equivalent strong coding agent).  
  No human hand-written implementation code is permitted after initial bootstrapping.

- **Strict spec separation**  
  Human/AI-refined specifications live only in VISION.md, CodeGenSpecs/, and per-agent folders.  
  Generated artifacts (code, README, docs) are never manually edited — update specs and re-generate.

- **Swift Version**: Swift 6.2 or later (minimum language and deployment target)  
  Rationale: Required for strict concurrency checking by default, refined actor isolation rules, improved Observation framework behaviors, performance enhancements for low-level code safety, and the latest concurrency features (detached tasks, nonisolated(unsafe) where justified, etc.).  
  All code must compile cleanly with Swift 6.2+ in strict concurrency mode (no data-race or concurrency-related warnings).

- **Platforms & Device Compatibility**  
  - iOS 26+, iPadOS 26+  
  - macOS 26+  
  - visionOS 2.4+ (with expansions in visionOS 26+)  
  Agents prioritize on-device processing via the Foundation Models framework (available on Apple Intelligence-compatible devices: iPhone 15 Pro/Max and later, iPad with A17 Pro or M-series, Mac with M1+, Apple Vision Pro).  
  Hybrid cloud fallback is supported for broader compatibility, but on-device performance/privacy is the default goal where available.

- **Dependencies**
  Only Foundation, the Foundation Models framework (conditional), and SwiftSynapseHarness (which re-exports all sub-packages):

  | Package | Role |
  |---------|------|
  | `SwiftOpenResponsesDSL` | Base LLM communication — `ResponseRequest`, `LLMClient`, `ResponseObject`, `TranscriptEntry` |
  | `SwiftLLMToolMacros` | Tool macros — `@LLMTool`, `@LLMToolArguments` generate `FunctionToolParam` schemas |
  | `SwiftOpenSkills` | agentskills.io standard — `SkillStore`, `SkillsAgent`, skill discovery |
  | `SwiftSynapseHarness` | **Unified agent harness** — re-exports all packages above; provides the complete agent infrastructure organized via Package Traits |

  ### Dependency hierarchy

  ```
  SwiftOpenResponsesDSL          ← base: all LLM I/O flows through this
      ├── SwiftLLMToolMacros     ← tool definition macros
      └── SwiftOpenSkills        ← agentskills.io standard
  SwiftSynapseHarness            ← unified harness: re-exports everything above
      ├── Core trait             ← tools, config, caching, shutdown, runtime, context, prompt builder
      ├── Hooks trait            ← 16 lifecycle events, hook pipeline
      ├── Safety trait           ← permissions, guardrails, content filtering
      ├── Resilience trait       ← recovery strategies, rate limiting, transcript repair
      ├── Observability trait    ← telemetry, cost tracking, token usage
      ├── MultiAgent trait       ← coordination, subagents, shared memory
      ├── Persistence trait      ← session storage, agent memory
      ├── MCP trait              ← Model Context Protocol (stdio/SSE/WebSocket)
      └── Plugins trait          ← modular extension system
  ```

  ### Harness Trait System (SwiftPM Package Traits, SE-0450)

  The harness uses Package Traits for modular feature selection. Agents opt into capabilities via trait declarations:

  | Composite Trait | Includes | Use Case |
  |-----------------|----------|----------|
  | **Production** (default) | Core + Hooks + Safety + Resilience + Observability | Most agents — full lifecycle with safety and monitoring |
  | **Advanced** | Production + MultiAgent + Persistence + MCP + Plugins | Complex agents needing coordination, memory, or external data |
  | **Full** | All traits | Development and testing |

  Unused traits compile to no-op stubs via `TraitStubs.swift` — zero overhead for disabled features.

  **Key rule for code generation:** import `SwiftSynapseHarness` for every agent actor — it re-exports all sub-packages, so a single import covers all types. Import `Foundation` explicitly only if the agent uses `URL` or other Foundation types directly. Import `FoundationModels` inside `#if canImport(FoundationModels)` guards for on-device inference.

- **Core Technical Patterns**  
  - Heavy use of macros for type-safe tools, structured outputs, and observability  
  - Actors for safe state management (all mutable registries are actors)  
  - @Observable transcripts for rich SwiftUI interfaces  
  - Swift concurrency (async/await, detached tasks, TaskGroup)  
  - Background continuation via BGContinuedProcessingTask  
  - On-device priority (Apple Foundation Models framework) with OpenAI-compatible cloud fallback when needed  
  - Hook-driven lifecycle with 16 interception points  
  - Policy-based permissions and guardrails for safe tool execution  
  - Recovery chains for self-healing from context overflow and output truncation  
  - Modular feature selection via Package Traits (SE-0450)

## Agent Showcase

### Foundation Agents (building blocks)
- **SimpleEcho**: No LLM — validates spec-to-codegen pipeline.
- **LLMChat**: Single LLM call — basic cloud inference.
- **LLMChatPersonas**: Two-step pipeline — persona rewrite via conversation threading.
- **RetryingLLMChatAgent**: Exponential-backoff retry with transcript annotations.
- **StreamingChatAgent**: Token-by-token streaming with observable transcript.
- **ToolUsingAgent**: Tool dispatch loop with calculate/convertUnit/formatNumber.
- **SkillsEnabledAgent**: agentskills.io skill discovery and activation.

### Advanced Agents (full harness coverage)
- **PRReviewer** (Safety trait): Guardrails, permissions, human-in-the-loop approval, content filtering, result truncation, streaming tool execution. *Parity: AutoGen human-in-the-loop, LangGraph approval gates.*
- **PerformanceOptimizer** (Resilience trait): Recovery chains, rate limiting, transcript integrity, graceful shutdown. *Parity: LangGraph error recovery, CrewAI rate limit handling.*
- **ResearchAssistant** (Persistence + MCP traits): Session persistence, cross-session memory, MCP external data sources, context budget management. *Parity: CrewAI memory, LangGraph checkpointing.*
- **TaskPlanner** (MultiAgent + Observability traits): Multi-agent coordination, subagent spawning, shared mailbox, team memory, cost tracking, full telemetry. *Parity: CrewAI multi-agent crews, Agency Swarm agent teams.*
- **DataPipelineAgent** (Plugins trait): Plugin-extensible data processing where each data source self-registers tools, hooks, and prompt sections. *Parity: LangGraph composable nodes, Agency Swarm extensible capabilities.*

### Template
- **TemplateAgent**: Scaffold for new agents — copy, write specs, and generate code.

(More examples to be added via community contributions.)

## Success Criteria
- Clone repo → open in Xcode → run AgentDashboard app → see live agent reasoning, tool calls, structured outputs, and UI updates.
- Agents are fully observable (thoughts, steps, tool results, errors) via transcript views.
- Background execution works: start agent in foreground → background app → resume on foreground.
- New agents can be added by copying TemplateAgent/, writing specs, and generating code.
- All code compiles cleanly with Swift 6.2+ strict concurrency mode.
- Project remains dependency-light and Apple-native, with on-device emphasis where supported.

## License

MIT License — see [LICENSE](LICENSE) for full text.

## Branding & Identity
- **Name**: SwiftSynapse  
- **Tagline**: "Smart, autonomous agents in pure Swift — connected intelligence for Apple platforms"  
- **Web presence**: swiftsynapse.dev (or similar) to be registered for documentation/landing page  
- Note: Not affiliated with unrelated sites like swiftsynapse.com (entrepreneur automation tools)

Last updated: April 2, 2026