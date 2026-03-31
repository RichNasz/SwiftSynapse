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

SwiftSynapse is an open-source framework for building smart, autonomous AI agents natively in Swift — with no Python bridges, no heavy external runtimes, and no compromises on type safety or platform integration. Every agent is **observable**, **background-capable**, and **macro-powered**: reasoning steps, tool calls, and streaming output surface directly in SwiftUI with zero Combine plumbing.

The framework provides a **shared agent harness** — `AgentConfiguration`, `retryWithBackoff`, `ToolExecutor`, `AgentLLMClient`, `AgentSession` — so building a new agent is ~30-50 lines of domain logic. Agents can discover and use [agentskills.io](https://agentskills.io) skills natively via **SwiftOpenSkills** integration.

This project follows a strict **spec-driven development (SDD)** workflow: every `.swift` file is a generated artifact. Human authors write and refine Markdown specifications; Claude Code (or an equivalent AI agent) produces all implementation code from those specs. Generated files are never edited manually — to change behavior, update the spec and regenerate.

---

## Key Features

- **Shared Agent Harness** — `AgentConfiguration`, `retryWithBackoff`, `ToolExecutor`, `AgentLLMClient` eliminate boilerplate; new agents are ~30-50 lines
- **Spec-Driven Development** — every agent is defined by a `SPEC.md`; all Swift code is generated from it, never hand-written
- **Observable Agents** — `@Observable` state exposes live transcript, tool calls, and reasoning steps directly to SwiftUI views via `ObservableTranscript`
- **Skills Integration** — [agentskills.io](https://agentskills.io) standard supported natively via `SkillStore`, `SkillsAgent`, and `activate_skill` tool
- **Type-Safe Tools** — `@LLMTool` macros generate JSON schemas at compile time; no stringly-typed dispatch, no runtime schema errors
- **On-Device Priority** — Apple Foundation Models framework used first on iOS 26+ / macOS 26+ / visionOS 2.4+ for full privacy
- **Hybrid Cloud Fallback** — transparent fallback to any OpenAI-compatible endpoint via `AgentLLMClient` when needed
- **Environment Configuration** — set `SWIFTSYNAPSE_SERVER_URL`, `SWIFTSYNAPSE_MODEL`, `SWIFTSYNAPSE_API_KEY` once; all CLIs pick them up
- **Pure Swift** — zero external runtimes, no Python bridges; only Foundation and the SwiftSynapse libraries
- **Apple-Native** — SwiftUI interfaces, `actor`-based agents, strict Swift 6.2+ concurrency throughout

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

**3. Configure your LLM endpoint (once)**

```bash
export SWIFTSYNAPSE_SERVER_URL=http://127.0.0.1:1234/v1/responses
export SWIFTSYNAPSE_MODEL=llama3
# export SWIFTSYNAPSE_API_KEY=sk-...  # if needed
```

**4. Run an agent from the CLI**

```bash
# Minimal echo agent (no LLM needed)
swift run simple-echo "Hello, SwiftSynapse!"

# Plain LLM reply
swift run llm-chat "What is the capital of France?"

# Persona-rewritten reply (prints original + persona version)
swift run llm-chat-personas "Explain black holes." --persona pirate

# Streaming response (token-by-token)
swift run streaming-chat-agent "Tell me a joke."

# LLM with retry on transient failures
swift run retrying-llm-chat-agent "Hello!" --max-retries 5

# Tool-using agent (math + unit conversion)
swift run tool-using-agent "Convert 100 miles to kilometers"

# Skills-enabled agent (discovers agentskills.io skills)
swift run skills-enabled-agent "Help me with my task"
```

All CLI options (`--server-url`, `--model`, `--api-key`) are optional when environment variables are set.

**5. Or invoke an agent in code**

```swift
import SwiftSynapseMacrosClient
import LLMChatAgent

// Configure once — validated at construction time
let config = try AgentConfiguration(
    serverURL: "http://127.0.0.1:1234/v1/responses",
    modelName: "llama3"
)

// Or resolve from environment variables
let config = try AgentConfiguration.fromEnvironment()

// Instantiate and run
let agent = try LLMChat(configuration: config)
let reply = try await agent.execute(goal: "Summarize the Swift 6.2 release notes.")
print(reply)

// Observe — transcript and status are @Observable; bind directly in SwiftUI
let transcript = await agent.transcript   // ObservableTranscript
let status = await agent.status           // AgentStatus
```

---

## Agent Examples

SwiftSynapse ships 7 runnable agents today. Every agent is fully spec-driven — no hand-written implementation code.

### Runnable now

| Agent | Description | Key Patterns Demonstrated |
|---|---|---|
| [SimpleEcho](./Agents/SimpleEcho/) | Echoes a goal string back with a prefix — the minimal `@SpecDrivenAgent` reference | `@SpecDrivenAgent` macro, transcript, status lifecycle |
| [LLMChat](./Agents/LLMChat/) | Forwards a prompt to any Open Responses API-compatible endpoint and returns the reply | `AgentConfiguration`, `retryWithBackoff`, `LLMClient` |
| [LLMChatPersonas](./Agents/LLMChatPersonas/) | Two-step pipeline: plain LLM response followed by an optional persona rewrite | Two-call pipeline, `PreviousResponseId` threading, `retryWithBackoff` |
| [RetryingLLMChatAgent](./Agents/RetryingLLMChatAgent/) | LLM chat with exponential-backoff retry on transient failures | Shared `retryWithBackoff`, retryable error classification |
| [StreamingChatAgent](./Agents/StreamingChatAgent/) | Streams LLM responses token-by-token with real-time transcript updates | `LLMClient.stream()`, `StreamEvent`, `setStreaming`/`appendDelta` lifecycle |
| [ToolUsingAgent](./Agents/ToolUsingAgent/) | Dispatches LLM-chosen tool calls for math and unit conversion | `ToolExecutor`, tool dispatch loop, `FunctionOutput`, `PreviousResponseId` |
| [SkillsEnabledAgent](./Agents/SkillsEnabledAgent/) | Discovers and activates agentskills.io skills from the filesystem | `SkillStore`, `SkillsAgent`, `activate_skill` tool, ~30 lines of domain logic |

### Showcase agents (in progress)

| Agent | Description | Key Patterns Demonstrated |
|---|---|---|
| PRReviewer | Analyzes GitHub PRs for style, performance, and security issues | Tool calling, structured patches, multi-phase review |
| TaskPlanner | Multi-phase productivity agent with sub-task tracking | Planning, verification, sub-agent orchestration |
| ResearchAssistant | Long-running research agent with session persistence | Memory, web tools, RAG, background continuation |

> New agents are bootstrapped from [Agents/TemplateAgent/specs/SPEC.md](./Agents/TemplateAgent/specs/SPEC.md). Copy it, fill in the spec, and run the generator.

---

## Shared Agent Harness

The harness provides shared types so agents stay lean. All types live in `SwiftSynapseMacrosClient`:

| Type | Purpose |
|---|---|
| `AgentConfiguration` | Centralized config — validates URLs, model names, timeouts, retry counts. `fromEnvironment()` reads `SWIFTSYNAPSE_*` env vars. |
| `retryWithBackoff` | Free async function — exponential backoff with `isTransportRetryable` predicate and `onRetry` callback |
| `ToolExecutor` | Actor — schedules tool calls respecting `isConcurrencySafe`, returns results in receive order |
| `AgentLLMClient` | Protocol — `send(_:)` / `stream(_:)` with `CloudLLMClient` and `HybridLLMClient` implementations |
| `AgentSession` | Codable struct — session persistence with `CodableTranscriptEntry` bridge |
| `AgentRuntime` | Static `execute()` — full tool dispatch loop with retry, transcript, and cancellation support |

### Minimal agent with the harness

```swift
import SwiftSynapseMacrosClient

@SpecDrivenAgent
public actor MyAgent {
    private let config: AgentConfiguration
    private let _llmClient: LLMClient

    public init(configuration: AgentConfiguration) throws {
        self.config = configuration
        self._llmClient = try configuration.buildLLMClient()
    }

    public func execute(goal: String) async throws -> String {
        _status = .running
        _transcript.reset()
        _transcript.append(.userMessage(goal))

        let timeout = TimeInterval(config.timeoutSeconds)
        let request = try ResponseRequest(model: config.modelName) {
            try RequestTimeout(timeout)
            try ResourceTimeout(timeout)
        } input: {
            User(goal)
        }

        let capturedClient = _llmClient
        let response = try await retryWithBackoff(maxAttempts: config.maxRetries) {
            try await capturedClient.send(request)
        }

        let text = response.firstOutputText ?? ""
        _transcript.append(.assistantMessage(text))
        _status = .completed(text)
        return text
    }
}
```

### Skills-enabled agent (~30 lines)

```swift
import SwiftSynapseMacrosClient

@SpecDrivenAgent
public actor MySkillsAgent {
    private let config: AgentConfiguration
    private let skillStore: SkillStore

    public init(configuration: AgentConfiguration) throws {
        self.config = configuration
        self.skillStore = SkillStore()
    }

    public func execute(goal: String) async throws -> String {
        _status = .running
        _transcript.reset()
        _transcript.append(.userMessage(goal))

        let store = skillStore
        try await store.load()

        let client = try config.buildLLMClient()
        let agent = try await SkillsAgent(client: client, model: config.modelName) {
            Skills(store: store)
        }

        let result = try await agent.send(goal)
        _transcript.append(.assistantMessage(result))
        _status = .completed(result)
        return result
    }
}
```

---

## How This Project Is Built (Spec-Driven Workflow)

SwiftSynapse is fully **AI-first**: no human writes implementation code. Every `.swift` file is a generated artifact produced by Claude Code reading a Markdown specification.

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

---

## Installation & Usage

SwiftSynapse agents depend on the macro libraries. Add them to your Swift package:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/RichNasz/SwiftSynapseMacros", branch: "main"),
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

> `SwiftSynapseMacrosClient` re-exports `SwiftOpenResponsesDSL`, `SwiftLLMToolMacros`, and `SwiftOpenSkills`, so a single import is all most agent files need.

> **Platform requirement:** On-device Foundation Models inference requires **iOS 26+**, **macOS 26+**, or **visionOS 2.4+** with Apple Intelligence enabled. For broader compatibility, point `AgentConfiguration` at any OpenAI-compatible cloud endpoint.

---

## Contributing

We welcome contributions — especially new agent specs, improvements to shared CodeGenSpecs, and infrastructure feedback.

### Adding a new agent

1. Copy `Agents/TemplateAgent/` -> `Agents/<YourAgentName>/`
2. Fill in `Agents/<YourAgentName>/specs/SPEC.md`
3. Customize `Agents/<YourAgentName>/specs/Overview.md` — reference shared types (`AgentConfiguration`, `retryWithBackoff`, `ToolExecutor`) instead of inline implementations
4. Run the generator (Claude Code) to produce `Sources/`, `CLI/`, and `Tests/` Swift files
5. Build and run `swift test` to verify all tests pass
6. Open a pull request containing spec files and generated output together

### Pull request guidelines

- PRs must not contain manually edited `.swift` files in `Sources/`, `CLI/`, or `Tests/`
- Spec changes and their generated output belong in the same commit
- Describe what the spec change achieves and how you verified the generated output

---

## License & Links

This project is released under the **MIT License** — use it, fork it, build on it.

### Related repositories

| Library | Purpose |
|---|---|
| [SwiftSynapseMacros](https://github.com/RichNasz/SwiftSynapseMacros) | Agent harness + macros — `@SpecDrivenAgent`, `AgentConfiguration`, `retryWithBackoff`, `ToolExecutor`, `AgentLLMClient` |
| [SwiftOpenResponsesDSL](https://github.com/RichNasz/SwiftOpenResponsesDSL) | Base LLM communication layer — `ResponseRequest`, `LLMClient`, `ResponseObject` |
| [SwiftLLMToolMacros](https://github.com/RichNasz/SwiftLLMToolMacros) | Tool definition macros — `@LLMTool` / `@LLMToolArguments` generate `FunctionToolParam` schemas |
| [SwiftOpenSkills](https://github.com/RichNasz/SwiftOpenSkills) | agentskills.io standard in Swift — `SkillStore`, `SkillsAgent`, skill discovery and activation |

Follow along: [@naszcyniec](https://x.com/naszcyniec) on X

---

<!-- Generated from CodeGenSpecs/README-Generation.md – Do not edit manually. Update spec and re-generate. -->
