<!-- Generated from CodeGenSpecs/README-Generation.md – Do not edit manually. Update spec and re-generate. -->

# SwiftSynapse

### Smart, autonomous agents in pure Swift — connected intelligence for Apple platforms

[![Swift](https://img.shields.io/badge/Swift-6.2%2B-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2026%2B%20%7C%20macOS%2026%2B%20%7C%20visionOS%202.4%2B-0078D4?style=flat-square&logo=apple&logoColor=white)](#)
[![License](https://img.shields.io/badge/License-MIT-brightgreen?style=flat-square)](#license)

```
  ◉ — ◉ — ◉
  |   |   |      SwiftSynapse
  ◉ — ◉ — ◉     connected intelligence, native Swift
  |   |   |
  ◉ — ◉ — ◉
```

![Agent Dashboard](Documentation/assets/dashboard.gif)

---

## Overview

SwiftSynapse is an open-source showcase and framework for building smart, autonomous AI agents natively in Swift — with no Python bridges, no heavy external runtimes, and no compromises on type safety or platform integration. Every agent we ship is **observable**, **background-capable**, and **macro-powered**: reasoning steps, tool calls, and streaming output surface directly in SwiftUI with zero Combine plumbing.

We built SwiftSynapse on three focused libraries — **SwiftSynapseMacros**, **SwiftOpenResponsesDSL**, and **SwiftLLMToolMacros** — that handle observability wiring, structured LLM output, and compile-time tool schemas respectively. Agents stay lean because the macro layer absorbs the boilerplate. On devices that support it (iOS 26+, macOS 26+), agents run on-device first via Apple's **Foundation Models** framework; a `LLMClient` protocol provides transparent fallback to OpenAI-compatible cloud endpoints.

This project follows a strict **spec-driven development (SDD)** workflow: every `.swift` file is a generated artifact. Human authors write and refine Markdown specifications; Claude Code (or an equivalent AI agent) produces all implementation code from those specs. Generated files are never edited manually — to change behavior, you update the spec and regenerate. See [VISION.md](./VISION.md) for the full project vision and non-negotiables.

---

## Key Features

- **Spec-Driven Development** — every agent is defined by a `SPEC.md`; all Swift code is generated from it, never hand-written
- **Observable Agents** — `@Observable` state exposes live transcript, tool calls, and reasoning steps directly to SwiftUI views
- **Background Execution** — agents register a `BGContinuedProcessingTask` and checkpoint progress, surviving app suspension cleanly
- **Type-Safe Tools** — `@LLMTool` macros generate JSON schemas at compile time; no stringly-typed dispatch, no runtime schema errors
- **On-Device Priority** — Apple Foundation Models framework used first on iOS 26+ / macOS 26+ / visionOS 2.4+ for full privacy
- **Hybrid Cloud Fallback** — transparent fallback to any OpenAI-compatible endpoint via the `LLMClient` protocol when needed
- **Pure Swift** — zero external runtimes, no Python bridges, no heavy AI SDKs; only Foundation and the SwiftSynapse macro libraries
- **Apple-Native** — SwiftUI interfaces, `@MainActor`-safe agents, actors, strict Swift 6.2 concurrency throughout

---

## 🚀 Quick Start

> **Note:** The Swift package and AgentDashboard app are generated artifacts produced once the first agent spec is finalized. The steps below reflect the workflow once generation is complete.

**1. Clone the repository**

```bash
git clone https://github.com/RichNasz/SwiftSynapse.git
cd SwiftSynapse
```

**2. Open in Xcode**

```bash
open Package.swift
```

**3. Select the AgentDashboard scheme and run**

The dashboard displays all available agents with their live transcript, tool calls, status, and streaming output in real time.

![Agent Dashboard running](Documentation/assets/dashboard-running.gif)

**4. Invoke an agent programmatically**

```swift
import SwiftSynapseMacros
import SwiftUI

// 1. Instantiate — inject the LLM client (on-device or cloud)
let agent = PRReviewerAgent(llmClient: FoundationModelsClient())

// 2. Run — structured input, async/await, strict concurrency
let output = try await agent.run(
    input: PRReviewerInput(
        repositoryURL: "https://github.com/owner/repo",
        pullRequestNumber: 42
    )
)

// 3. Observe — transcript updates in real time via @Observable
print(output.summary)
```

Bind the agent's live state to any SwiftUI view:

```swift
struct PRReviewerView: View {
    @State private var agent = PRReviewerAgent(llmClient: FoundationModelsClient())

    var body: some View {
        VStack {
            TranscriptView(transcript: agent.transcript)

            if agent.isRunning {
                ProgressView("Reviewing pull request…")
            }
        }
        .task {
            try? await agent.run(
                input: PRReviewerInput(
                    repositoryURL: "https://github.com/owner/repo",
                    pullRequestNumber: 42
                )
            )
        }
    }
}
```

---

## Agent Examples

The agents below are the showcase examples that define SwiftSynapse's scope. Each is specified by a `SPEC.md` and fully generated — no hand-written implementation code.

| Agent | Description | Key Patterns Demonstrated |
|---|---|---|
| [PRReviewer](./Agents/PRReviewer/SPEC.md) | Analyzes GitHub PRs for style, performance, and security issues; suggests concrete patches | Tool calling, structured patches, multi-phase review |
| [PerformanceOptimizer](./Agents/PerformanceOptimizer/SPEC.md) | Identifies bottlenecks in Swift code and proposes targeted optimizations | Benchmark tools, code rewrite suggestions, structured output |
| [TaskPlanner](./Agents/TaskPlanner/SPEC.md) | Multi-phase personal productivity agent that breaks goals into sub-tasks and tracks completion | Planning, verification, sub-agent orchestration, memory |
| [ResearchAssistant](./Agents/ResearchAssistant/SPEC.md) | Long-running research agent with retrieval-augmented generation and session persistence | Memory, web tools, RAG, background continuation |

> Agents are added incrementally. See [Agents/TemplateAgent/SPEC.md](./Agents/TemplateAgent/SPEC.md) for the scaffold used to bootstrap each one.

![Transcript view showing live tool calls](Documentation/assets/transcript-view.gif)

---

## How This Project Is Built (Spec-Driven Workflow)

SwiftSynapse is fully **AI-first**: no human writes implementation code. Every `.swift` file, every README, and every doc page is a generated artifact produced by Claude Code (or an equivalent AI generator) reading a Markdown specification.

### The workflow

```
┌─────────────────────────────────────────────┐
│  1. Write or refine a spec                  │
│     VISION.md / CodeGenSpecs/ / SPEC.md     │
└────────────────────┬────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────┐
│  2. Run the generator                       │
│     Claude Code reads spec → writes Swift   │
└────────────────────┬────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────┐
│  3. Review generated output                 │
│     Compile, test, iterate on spec if wrong │
└────────────────────┬────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────┐
│  4. Commit spec + generated artifacts       │
│     Never edit Generated/ files directly    │
└─────────────────────────────────────────────┘
```

### What lives where

| Path | What it contains | Who authors it |
|---|---|---|
| `VISION.md` | Project vision, goals, non-negotiables | Human |
| `CodeGenSpecs/` | Shared generation rules for all agents | Human |
| `Agents/<Name>/SPEC.md` | Per-agent goal, inputs, tasks, tools, outputs | Human |
| `Agents/<Name>/CodeGen/` | Agent-specific generation guidance | Human |
| `Agents/<Name>/Generated/` | Generated Swift implementation | AI (never edit) |
| `README.md` | This file | AI (never edit) |

**Transparency:** every generated `.swift` file opens with a header comment referencing the spec it was produced from:

```swift
// Generated from Agents/PRReviewer/SPEC.md
// Do not edit manually. Update spec and re-generate.
```

See [`CodeGenSpecs/Overview.md`](./CodeGenSpecs/Overview.md) for the full shared generation rules that apply to every agent.

---

## Installation & Usage

SwiftSynapse's generated agents depend on three macro libraries. Add them to your own Swift package:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/RichNasz/SwiftSynapseMacros", from: "0.1.0"),
    .package(url: "https://github.com/RichNasz/SwiftOpenResponsesDSL",  from: "0.1.0"),
    .package(url: "https://github.com/RichNasz/SwiftLLMToolMacros",  from: "0.1.0"),
],
targets: [
    .target(
        name: "YourApp",
        dependencies: [
            .product(name: "SwiftSynapseMacros", package: "SwiftSynapseMacros"),
            .product(name: "SwiftOpenResponsesDSL",  package: "SwiftOpenResponsesDSL"),
            .product(name: "SwiftLLMToolMacros", package: "SwiftLLMToolMacros"),
        ]
    )
]
```

> **Platform requirement:** On-device Foundation Models inference requires **iOS 26+**, **macOS 26+**, or **visionOS 2.4+** with Apple Intelligence enabled. The `FoundationModelsClient` will throw `LLMClientError.unsupportedPlatform` on earlier OS versions — catch it and fall back to a `CloudLLMClient` targeting any OpenAI-compatible endpoint.

### Minimal runtime example

```swift
import SwiftSynapseMacros
import SwiftOpenResponsesDSL

@Observable
@MainActor
final class MyAgent {
    private(set) var transcript = AgentTranscript()
    private(set) var status: MyAgentStatus = .idle
    var isRunning: Bool { status == .running }

    private let llmClient: any LLMClient

    init(llmClient: any LLMClient = FoundationModelsClient()) {
        self.llmClient = llmClient
    }

    func run(goal: String) async throws {
        status = .running
        defer { status = .idle }

        for try await delta in llmClient.stream(prompt: goal) {
            await transcript.apply(delta)
        }
    }
}
```

---

## Contributing

We welcome contributions — especially new agent specs, improvements to shared CodeGenSpecs, and infrastructure feedback.

### Adding a new agent

1. Copy `Agents/TemplateAgent/` → `Agents/<YourAgentName>/`
2. Fill in `Agents/<YourAgentName>/SPEC.md`:
   - **Goal** — one clear sentence describing what the agent does
   - **Input** — typed fields the agent receives
   - **Tasks** — ordered steps to achieve the goal
   - **Tools** — `@LLMTool`-decorated functions with side-effect declarations
   - **Output** — typed result the agent returns
   - **Constraints** — rules the agent must never violate
   - **Success criteria** — observable pass/fail conditions
3. Customize `Agents/<YourAgentName>/CodeGen/Overview.md` if the agent needs generation overrides
4. Run the generator to produce `Generated/` Swift files
5. Open a pull request containing the spec files and generated output only

### Pull request guidelines

- PRs must not contain manually edited `.swift` files inside any `Generated/` directory
- Spec changes and their generated output belong in the same commit
- Describe what the spec change achieves and how you verified the generated output (compile, run, transcript inspection)
- For spec-only PRs (no generation yet), prefix the title with `[Spec]`

### Issues

Use [GitHub Issues](https://github.com/RichNasz/SwiftSynapse/issues) to report bugs, propose new agents, or suggest improvements to shared specs. Prefix issue titles with the agent name or `[Core]` for shared infrastructure concerns.

---

## License & Links

This project is released under the **MIT License** — use it, fork it, build on it.

### Related repositories

| Library | Purpose |
|---|---|
| [SwiftSynapseMacros](https://github.com/RichNasz/SwiftSynapseMacros) | Core agent macros: observability, background execution, transcript |
| [SwiftOpenResponsesDSL](https://github.com/RichNasz/SwiftOpenResponsesDSL) | Result-builder DSL for structured LLM response construction |
| [SwiftLLMToolMacros](https://github.com/RichNasz/SwiftLLMToolMacros) | Compile-time `@LLMTool` schema generation and dispatch |

Follow along: [@naszcyniec](https://x.com/naszcyniec) on X

---

<!-- Generated from CodeGenSpecs/README-Generation.md – Do not edit manually. Update spec and re-generate. -->
