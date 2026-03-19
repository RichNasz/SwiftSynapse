# SwiftSynapse

**Smart, autonomous agents in pure Swift – connected intelligence for Apple platforms**

![Swift](https://img.shields.io/badge/Swift-6.2%2B-F05138?style=flat-square&logo=swift&logoColor=white)
![Platforms](https://img.shields.io/badge/Platforms-iOS%2018%20%C2%B7%20macOS%2015%20%C2%B7%20visionOS%202-0078D4?style=flat-square&logo=apple&logoColor=white)

---

## Overview

SwiftSynapse is an open-source showcase and framework for building production-grade, autonomous AI agents natively in Swift — no Python bridges, no heavy third-party AI frameworks, no compromises. Every agent is observable, background-capable, type-safe, and powered by a declarative macro stack that eliminates boilerplate and makes agent reasoning visible inside any SwiftUI interface.

The project targets Swift developers who want to adopt agentic AI patterns on Apple platforms without leaving the Swift ecosystem. Agents run on-device first via Apple's Foundation Models framework, with hybrid cloud fallback for tasks that require more capacity. A shared library layer — **SwiftSynapseMacros**, **SwiftResponsesDSL**, and **SwiftLLMToolMacros** — handles observability, structured LLM output, and tool schema generation at the macro level, so agents stay lean and readable.

SwiftSynapse follows a strict **spec-driven development (SDD)** workflow: every `.swift` file in this repository is a generated artifact. Human authors write and refine specifications; an AI generator produces all implementation code from those specs. Generated files are never edited manually. This makes the codebase fully auditable, regenerable, and safe to evolve by updating specs rather than hunting through source. See [VISION.md](./VISION.md) for the full project vision and non-negotiables.

---

## Features

- **Observable agents** — every agent exposes status, transcript, and progress via `@Observable`; SwiftUI views bind directly with no Combine plumbing
- **Background execution** — agents survive app suspension via `BGContinuedProcessingTask` and Swift structured concurrency; work checkpoints automatically
- **Type-safe tool calling** — `@LLMTool` macros generate JSON schemas at compile time; no stringly-typed tool dispatch
- **Streaming transcripts** — `AsyncStream<TranscriptDelta>` delivers token-by-token reasoning and tool-call events in real time
- **Foundation Models compatible** — on-device LLM priority using Apple's Foundation Models API; cloud providers are plug-in replacements via `LLMClient` protocol
- **SwiftUI-ready** — agents are `@Observable` and `@MainActor`-safe; drop them directly into any SwiftUI view hierarchy
- **Strict concurrency** — Swift 6.2 strict mode throughout; actors, `Sendable`, and structured concurrency used consistently
- **Zero extra runtime dependencies** — only Foundation, the SwiftSynapse macro libraries, and Apple's platform frameworks
- **Macro-powered** — tool schemas, structured output, and observability wiring are all generated at compile time via Swift macros

---

## Quick Start

> **Note:** The Swift package and AgentDashboard app are generated artifacts — they will be produced once the first agent spec is finalized. The steps below reflect the intended workflow once generation is complete.

### 1. Clone the repository

```bash
git clone https://github.com/RichNasz/SwiftSynapse.git
cd SwiftSynapse
```

### 2. Open in Xcode

```bash
open Package.swift
```

### 3. Run the AgentDashboard

Select the **AgentDashboard** scheme in Xcode and press Run. The dashboard displays all available agents, their live transcript, tool calls, and status in real time.

### What a generated agent looks like

The snippet below illustrates the pattern that the generator produces for every agent. It is not hand-written — it is the output you get by writing a `SPEC.md` and running the generator:

```swift
import Observation
import SwiftSynapseMacros

@Observable
@MainActor
final class PRReviewerAgent {
    private(set) var status: PRReviewerStatus = .idle
    private(set) var transcript = AgentTranscript()
    var isRunning: Bool { status == .running }

    private let llmClient: any LLMClient

    init(llmClient: any LLMClient) {
        self.llmClient = llmClient
    }

    func run(input: PRReviewerInput) async throws -> PRReviewerOutput {
        status = .running
        defer { status = .idle }
        // Generated tool dispatch and LLM interaction loop lives here.
        // Do not edit — regenerate from Agents/PRReviewer/SPEC.md instead.
        fatalError("Regenerate from spec")
    }
}
```

And a minimal SwiftUI binding:

```swift
import SwiftUI

struct PRReviewerView: View {
    @State private var agent = PRReviewerAgent(llmClient: FoundationModelsClient())

    var body: some View {
        TranscriptView(transcript: agent.transcript)
            .overlay(alignment: .bottom) {
                if agent.isRunning {
                    ProgressView("Reviewing…")
                }
            }
            .task {
                try? await agent.run(input: .init(prURL: "https://github.com/…"))
            }
    }
}
```

---

## Agent Examples

### TemplateAgent

A scaffold that demonstrates the required structure for any SwiftSynapse agent. Use it as the starting point when adding a new agent to the repository.

**Spec:** [Agents/TemplateAgent/SPEC.md](./Agents/TemplateAgent/SPEC.md)
**CodeGen guidance:** [Agents/TemplateAgent/CodeGen/Overview.md](./Agents/TemplateAgent/CodeGen/Overview.md)

```swift
// Generated output shape for any agent built from TemplateAgent.
// Actual implementation is produced by the generator — not written by hand.

@Observable
@MainActor
final class TemplateAgent {
    private(set) var status: TemplateAgentStatus = .idle
    private(set) var transcript = AgentTranscript()
    var isRunning: Bool { status == .running }

    func run(input: TemplateAgentInput) async throws -> TemplateAgentOutput {
        status = .running
        defer { status = .idle }
        // Implement via spec → generate workflow.
        fatalError("Replace with generated implementation")
    }
}
```

---

## SDD Workflow (Spec-Driven Development)

All code in SwiftSynapse is produced by a generator, never written by hand. The workflow is:

```
1. Write (or update) a SPEC.md
       │
       ▼
2. Run the generator
   swift run SwiftSynapseCodeGen --agent <AgentName>
       │
       ▼
3. Generator reads SPEC.md + all CodeGenSpecs/
   and writes Generated/ Swift files
       │
       ▼
4. Never edit Generated/ files directly.
   To change behavior → go back to step 1.
```

**Shared generation rules** that apply to every agent live in [`CodeGenSpecs/`](./CodeGenSpecs/Overview.md). Each agent's folder contains its own `SPEC.md` and a `CodeGen/` directory with agent-specific generation guidance.

The benefit: any agent can be fully regenerated from its spec at any time. The spec is the source of truth — not the code.

---

## Contributing

### Adding a new agent

1. Copy `Agents/TemplateAgent/` to `Agents/<YourAgentName>/`
2. Fill in `Agents/<YourAgentName>/SPEC.md` — goal, inputs, tasks, tools, outputs, constraints, success criteria
3. Optionally add agent-specific generation notes to `Agents/<YourAgentName>/CodeGen/Overview.md`
4. Run the generator to produce the implementation
5. Open a PR with only the spec files and generated output — no hand-written `.swift` files

### Pull requests

- PRs must not contain manually edited `.swift` files in `Generated/` directories
- Spec changes and generated output should be in the same commit
- Include a short description of what the spec change achieves and how you verified the generated output

### Issues

Use [GitHub Issues](https://github.com/RichNasz/SwiftSynapse/issues) to report bugs, propose new agents, or suggest spec improvements. Prefix issue titles with the relevant agent name or `[Core]` for shared infrastructure.

---

> **Generated artifact** — this file was produced from [CodeGenSpecs/README-Generation.md](./CodeGenSpecs/README-Generation.md) and [VISION.md](./VISION.md). Do not edit manually. To update, modify the relevant spec and regenerate.
