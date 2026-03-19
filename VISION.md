# SwiftSynapse — Vision

> A showcase repository for autonomous, observable, background-capable AI agents built in pure Swift.

---

## What Is SwiftSynapse?

SwiftSynapse demonstrates how to build production-quality AI agents entirely in Swift — with zero external AI framework dependencies — using Apple's first-party technologies and a small set of focused macro libraries.

Every agent in this repository is generated from a machine-readable specification. No implementation code is written by hand. The spec drives the code; the code is never edited directly.

---

## Goals

- Demonstrate end-to-end AI agent patterns in idiomatic Swift 6.2+
- Showcase autonomous background agents that survive app suspension
- Provide a reusable template and spec-driven workflow for new agents
- Serve as a living reference for the SwiftSynapseMacros, SwiftResponsesDSL, and SwiftLLMToolMacros libraries

---

## Target Platforms

| Platform   | Minimum Version |
|------------|----------------|
| iOS        | 18.0+          |
| macOS      | 15.0+          |
| visionOS   | 2.0+           |

---

## Core Principles

1. **Type-safety first.** All agent inputs, outputs, and tool calls are statically typed. No stringly-typed APIs.
2. **Zero extra dependencies.** Only Apple frameworks, plus the SwiftSynapse macro libraries. No Python bridges, no third-party AI SDKs.
3. **AI-first generation.** All implementation code is generated from specifications by an AI. Human authors write specs, not code.
4. **Observable agents.** Every agent exposes its state, transcript, and progress through the `Observation` framework (`@Observable`). SwiftUI views bind directly to agent state.
5. **Background-capable.** Agents can continue processing when the app moves to the background, using Swift concurrency (`async`/`await`, `Task`, `AsyncStream`) and `BGContinuedProcessingTask`.
6. **Foundation Models compatible.** All LLM integrations are designed to work with Apple's on-device Foundation Models framework as well as remote providers.

---

## Non-Negotiables

- **No hand-written implementation code.** All `.swift` files are generated artifacts. The authoritative source of truth is always the spec.
- **Swift 6.2+.** The codebase uses strict concurrency checking and modern Swift features throughout.
- **Observation framework.** Agent state is exposed via `@Observable`, never `ObservableObject` / Combine.
- **Foundation Models compatible.** Agent tool schemas and prompt structures must remain compatible with Apple's Foundation Models APIs.
- **Spec-first.** Any change to behavior begins with a change to the relevant `SPEC.md` or `CodeGenSpecs/` file. Never the reverse.
