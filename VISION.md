# SwiftSynapse Project Vision

## Overview
SwiftSynapse is an open-source showcase and foundational framework for building **smart, autonomous AI agents** natively in pure Swift for Apple platforms.

The project demonstrates production-grade agentic patterns using:
- Declarative macros (via SwiftSynapseMacros)
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
  Only Foundation + the three core packages (no additional runtime dependencies):

  | Package | Role |
  |---------|------|
  | `SwiftOpenResponsesDSL` | Base LLM communication layer — constructs `ResponseRequest` objects, sends them to Open Responses API-compatible endpoints, and parses `ResponseObject` replies |
  | `SwiftSynapseMacros` | Agent creation layer — depends on `SwiftOpenResponsesDSL`; provides `@SpecDrivenAgent` and related macros that synthesize boilerplate state, lifecycle, and transcript management for agent types |
  | `SwiftLLMToolMacros` | Tool definition layer — depends on `SwiftOpenResponsesDSL`; provides `@LLMTool`, `@LLMToolArguments`, and `@LLMToolGuide` macros that generate type-safe `FunctionToolParam` schemas for use in `ResponseRequest` |

  ### Dependency hierarchy

  ```
  SwiftOpenResponsesDSL          ← base: all LLM I/O flows through this
      ├── SwiftSynapseMacros     ← builds on SwiftOpenResponsesDSL to simplify agent structure
      └── SwiftLLMToolMacros     ← builds on SwiftOpenResponsesDSL to simplify tool definitions
  ```

  **Key rule for code generation:** import the package that matches the concern:
  - LLM requests/responses → `SwiftOpenResponsesDSL`
  - Agent scaffolding (status, transcript, macro-generated init) → `SwiftSynapseMacros`
  - Tool structs (`@LLMTool`, `@LLMToolArguments`) → `SwiftLLMToolMacros`

- **Core Technical Patterns**  
  - Heavy use of macros for type-safe tools, structured outputs, and observability  
  - Actors for safe state management  
  - @Observable transcripts for rich SwiftUI interfaces  
  - Swift concurrency (async/await, detached tasks, TaskGroup)  
  - Background continuation via BGContinuedProcessingTask  
  - On-device priority (Apple Foundation Models framework) with OpenAI-compatible cloud fallback when needed

## Target Use Cases in Showcase
- PRReviewer: Analyzes GitHub PRs for Swift style, performance, security; suggests ready-to-apply patches.
- PerformanceOptimizer: Identifies bottlenecks in Swift code/packages; proposes optimized implementations.
- TaskPlanner: Multi-phase personal productivity agent with planning, sub-agents, and verification.
- ResearchAssistant: Long-running research with memory/RAG, web tools, and persistent sessions.
- (more examples to be added via community contributions)

## Success Criteria
- Clone repo → open in Xcode → run AgentDashboard app → see live agent reasoning, tool calls, structured outputs, and UI updates.
- Agents are fully observable (thoughts, steps, tool results, errors) via transcript views.
- Background execution works: start agent in foreground → background app → resume on foreground.
- New agents can be added by copying TemplateAgent/, writing specs, and generating code.
- All code compiles cleanly with Swift 6.2+ strict concurrency mode.
- Project remains dependency-light and Apple-native, with on-device emphasis where supported.

## Branding & Identity
- **Name**: SwiftSynapse  
- **Tagline**: "Smart, autonomous agents in pure Swift — connected intelligence for Apple platforms"  
- **Web presence**: swiftsynapse.dev (or similar) to be registered for documentation/landing page  
- Note: Not affiliated with unrelated sites like swiftsynapse.com (entrepreneur automation tools)

Last updated: March 19, 2026