<!-- Generated from CodeGenSpecs/README-Generation.md – Do not edit manually. Update spec and re-generate. -->

# SwiftSynapse

### Smart, autonomous agents in pure Swift — connected intelligence for Apple platforms

[![Swift](https://img.shields.io/badge/Swift-6.2%2B-F05138?style=flat-square&logo=swift&logoColor=white)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%2026%2B%20%7C%20macOS%2026%2B%20%7C%20visionOS%202.4%2B-0078D4?style=flat-square&logo=apple&logoColor=white)](#)
[![License](https://img.shields.io/badge/License-MIT-brightgreen?style=flat-square)](#license--links)

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

We built SwiftSynapse on three focused libraries — **SwiftSynapseMacros**, **SwiftOpenResponsesDSL**, and **SwiftLLMToolMacros** — that handle agent scaffolding, structured LLM communication, and compile-time tool schemas respectively. Agents stay lean because the macro layer absorbs the boilerplate. On devices that support it (iOS 26+, macOS 26+), agents run on-device first via Apple's **Foundation Models** framework; `LLMClient` provides transparent fallback to any OpenAI-compatible cloud endpoint.

This project follows a strict **spec-driven development (SDD)** workflow: every `.swift` file is a generated artifact. Human authors write and refine Markdown specifications; Claude Code (or an equivalent AI agent) produces all implementation code from those specs. Generated files are never edited manually — to change behavior, update the spec and regenerate. See [VISION.md](./VISION.md) for the full project vision and non-negotiables.

---

## Key Features

- **Spec-Driven Development** — every agent is defined by a `SPEC.md`; all Swift code is generated from it, never hand-written
- **Observable Agents** — `@Observable` state exposes live transcript, tool calls, and reasoning steps directly to SwiftUI views via `ObservableTranscript`
- **Background Execution** — agents register a `BGContinuedProcessingTask` and checkpoint progress, surviving app suspension cleanly
- **Type-Safe Tools** — `@LLMTool` macros generate JSON schemas at compile time; no stringly-typed dispatch, no runtime schema errors
- **On-Device Priority** — Apple Foundation Models framework used first on iOS 26+ / macOS 26+ / visionOS 2.4+ for full privacy
- **Hybrid Cloud Fallback** — transparent fallback to any OpenAI-compatible endpoint via `LLMClient` when needed
- **Pure Swift** — zero external runtimes, no Python bridges, no heavy AI SDKs; only Foundation and the three SwiftSynapse libraries
- **Apple-Native** — SwiftUI interfaces, `actor`-based agents, strict Swift 6.2 concurrency throughout

---

## Quick Start

**1. Clone the repository**

```bash
git clone https://github.com/RichNasz/SwiftSynapse.git
cd SwiftSynapse
```

**2. Open in Xcode**

```bash
open Package.swift
```

**3. Run an agent from the CLI**

```bash
# Plain LLM reply
swift run llm-chat "What is the capital of France?" \
    --server-url http://127.0.0.1:1234/v1/responses \
    --model llama3

# Persona-rewritten reply (prints original + persona version)
swift run llm-chat-personas "Explain black holes." \
    --server-url http://127.0.0.1:1234/v1/responses \
    --model llama3 \
    --persona pirate
```

**4. Or invoke an agent in code**

```swift
import LLMChatAgent

// Instantiate — provide an Open Responses API endpoint
let agent = try LLMChat(
    serverURL: "http://127.0.0.1:1234/v1/responses",
    modelName: "llama3"
)

// Run — async/await, strict concurrency
let reply = try await agent.execute(goal: "Summarize the Swift 6.2 release notes.")
print(reply)

// Observe — transcript and status are @Observable; bind directly in SwiftUI
let transcript = await agent.transcript   // ObservableTranscript
let status = await agent.status           // AgentStatus
```

Bind live agent state to any SwiftUI view:

```swift
struct ChatView: View {
    @State private var agent = try! LLMChat(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "llama3"
    )
    @State private var goal = ""

    var body: some View {
        VStack {
            // agent.transcript.entries updates automatically — bind to a list
            TranscriptView(entries: agent.transcript.entries)

            if case .running = agent.status {
                ProgressView("Thinking...")
            }
        }
        .task {
            try? await agent.execute(goal: goal)
        }
    }
}
```

![Agent Dashboard running](Documentation/assets/dashboard-running.gif)

---

## Agent Examples

SwiftSynapse ships runnable agents today, with larger showcase agents in progress. Every agent is fully spec-driven — no hand-written implementation code.

### Runnable now

| Agent | Description | Key Patterns Demonstrated |
|---|---|---|
| [SimpleEcho](./Agents/SimpleEcho/specs/SPEC.md) | Echoes a goal string back with a prefix — the minimal `@SpecDrivenAgent` reference | `@SpecDrivenAgent` macro, transcript, status lifecycle |
| [LLMChat](./Agents/LLMChat/specs/SPEC.md) | Forwards a prompt to any Open Responses API-compatible endpoint and returns the reply | `LLMClient`, `ResponseRequest` DSL, `RequestTimeout`, error handling |
| [LLMChatPersonas](./Agents/LLMChatPersonas/specs/SPEC.md) | Two-step pipeline: plain LLM response followed by an optional persona rewrite using conversation threading | Two-call pipeline, `PreviousResponseId` threading, dual CLI output |

### Showcase agents (in progress)

| Agent | Description | Key Patterns Demonstrated |
|---|---|---|
| PRReviewer | Analyzes GitHub PRs for style, performance, and security issues; suggests concrete patches | Tool calling, structured patches, multi-phase review |
| PerformanceOptimizer | Identifies bottlenecks in Swift code and proposes targeted optimizations | Benchmark tools, code rewrite suggestions, structured output |
| TaskPlanner | Multi-phase personal productivity agent that breaks goals into sub-tasks and tracks completion | Planning, verification, sub-agent orchestration, memory |
| ResearchAssistant | Long-running research agent with retrieval-augmented generation and session persistence | Memory, web tools, RAG, background continuation |

> New agents are bootstrapped from [Agents/TemplateAgent/specs/SPEC.md](./Agents/TemplateAgent/specs/SPEC.md). Copy it, fill in the spec, and run the generator.

![Transcript view showing live tool calls](Documentation/assets/transcript-view.gif)

---

## How This Project Is Built (Spec-Driven Workflow)

SwiftSynapse is fully **AI-first**: no human writes implementation code. Every `.swift` file, every README, and every doc page is a generated artifact produced by Claude Code (or an equivalent AI generator) reading a Markdown specification.

### The workflow

```
+---------------------------------------------+
|  1. Write or refine a spec                  |
|     VISION.md / CodeGenSpecs/ / SPEC.md     |
+--------------------+------------------------+
                     |
                     v
+---------------------------------------------+
|  2. Run the generator                       |
|     Claude Code reads spec -> writes Swift  |
+--------------------+------------------------+
                     |
                     v
+---------------------------------------------+
|  3. Review generated output                 |
|     Compile, test, iterate on spec if wrong |
+--------------------+------------------------+
                     |
                     v
+---------------------------------------------+
|  4. Commit spec + generated artifacts       |
|     Never edit generated .swift files       |
+---------------------------------------------+
```

### What lives where

| Path | What it contains | Who authors it |
|---|---|---|
| `VISION.md` | Project vision, goals, non-negotiables | Human |
| `CodeGenSpecs/` | Shared generation rules for all agents | Human |
| `Agents/<Name>/specs/SPEC.md` | Per-agent goal, inputs, tasks, tools, outputs | Human |
| `Agents/<Name>/specs/Overview.md` | Agent-specific generation guidance | Human |
| `Agents/<Name>/Sources/` | Generated Swift implementation | AI (never edit) |
| `README.md` | This file | AI (never edit) |

**Transparency:** every generated `.swift` file opens with a header comment referencing the spec it was produced from:

```swift
// Generated strictly from Agents/LLMChat/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate
```

See [`CodeGenSpecs/Overview.md`](./CodeGenSpecs/Overview.md) for the shared generation rules applied to every agent.

---

## Installation & Usage

SwiftSynapse agents depend on three macro libraries. Add them to your own Swift package:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/RichNasz/SwiftSynapseMacros", branch: "main"),
    .package(url: "https://github.com/RichNasz/SwiftOpenResponsesDSL", branch: "main"),
    .package(url: "https://github.com/RichNasz/SwiftLLMToolMacros",   branch: "main"),
],
targets: [
    .target(
        name: "YourAgent",
        dependencies: [
            .product(name: "SwiftSynapseMacrosClient", package: "SwiftSynapseMacros"),
        ]
    )
]
```

> `SwiftSynapseMacrosClient` re-exports both `SwiftOpenResponsesDSL` and `SwiftLLMToolMacros`, so a single import is all most agent files need.

> **Platform requirement:** On-device Foundation Models inference requires **iOS 26+**, **macOS 26+**, or **visionOS 2.4+** with Apple Intelligence enabled. For broader compatibility, point `LLMClient` at any OpenAI-compatible cloud endpoint instead.

### Minimal agent example

```swift
import SwiftSynapseMacrosClient

@SpecDrivenAgent
public actor MyAgent {
    private let modelName: String
    private let _llmClient: LLMClient

    public init(serverURL: String, modelName: String, apiKey: String? = nil) throws {
        self.modelName = modelName
        self._llmClient = try LLMClient(baseURL: serverURL, apiKey: apiKey ?? "")
    }

    public func execute(goal: String) async throws -> String {
        _status = .running
        _transcript.append(.userMessage(goal))

        let request = try ResponseRequest(model: modelName) {
            try RequestTimeout(300)
            try ResourceTimeout(300)
        } input: {
            User(goal)
        }

        let response = try await _llmClient.send(request)
        let text = response.firstOutputText ?? ""

        _transcript.append(.assistantMessage(text))
        _status = .completed(text)
        return text
    }
}
```

The `@SpecDrivenAgent` macro generates `_status`, `_transcript`, `_client`, `status`, `transcript`, `client`, `configure(client:)`, and `run(goal:)` — all the boilerplate an observable agent needs. Agent-specific logic goes in `execute(goal:)`.

---

## Contributing

We welcome contributions — especially new agent specs, improvements to shared CodeGenSpecs, and infrastructure feedback.

### Adding a new agent

1. Copy `Agents/TemplateAgent/` -> `Agents/<YourAgentName>/`
2. Fill in `Agents/<YourAgentName>/specs/SPEC.md`:
   - **Goal** — one clear sentence describing what the agent does
   - **Configuration** — constructor parameters (URLs, model names, keys)
   - **Input** — typed fields the agent receives at `execute()` time
   - **Tasks** — ordered steps to achieve the goal
   - **Tools** — `@LLMTool`-decorated structs with side-effect declarations
   - **Output** — typed result the agent returns
   - **Errors** — named error cases and when each is thrown
   - **Success criteria** — observable pass/fail conditions
3. Customize `Agents/<YourAgentName>/specs/Overview.md` for agent-specific generation guidance
4. Run the generator (Claude Code) to produce `Sources/`, `CLI/`, and `Tests/` Swift files
5. Build and run `swift test` to verify all tests pass
6. Open a pull request containing spec files and generated output together

### Pull request guidelines

- PRs must not contain manually edited `.swift` files in `Sources/`, `CLI/`, or `Tests/`
- Spec changes and their generated output belong in the same commit
- Describe what the spec change achieves and how you verified the generated output (compile, test, transcript inspection)
- For spec-only PRs (no generation yet), prefix the title with `[Spec]`

### Issues

Use [GitHub Issues](https://github.com/RichNasz/SwiftSynapse/issues) to report bugs, propose new agents, or suggest improvements to shared specs. Prefix issue titles with the agent name or `[Core]` for shared infrastructure concerns.

---

## License & Links

This project is released under the **MIT License** — use it, fork it, build on it.

### Related repositories

| Library | Purpose |
|---|---|
| [SwiftSynapseMacros](https://github.com/RichNasz/SwiftSynapseMacros) | Agent creation macros — `@SpecDrivenAgent` synthesizes agent boilerplate |
| [SwiftOpenResponsesDSL](https://github.com/RichNasz/SwiftOpenResponsesDSL) | Base LLM communication layer — `ResponseRequest`, `LLMClient`, `ResponseObject` |
| [SwiftLLMToolMacros](https://github.com/RichNasz/SwiftLLMToolMacros) | Tool definition macros — `@LLMTool` / `@LLMToolArguments` generate `FunctionToolParam` schemas |

Follow along: [@naszcyniec](https://x.com/naszcyniec) on X

---

<!-- Generated from CodeGenSpecs/README-Generation.md – Do not edit manually. Update spec and re-generate. -->
