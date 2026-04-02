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

Agents delegate to [SwiftOpenResponsesDSL](https://github.com/RichNasz/SwiftOpenResponsesDSL)'s `Agent` actor for LLM communication, tool dispatch, and conversation continuity — so building a new agent is **~30 lines of domain logic**. Drop-in **SwiftUI components** from `SwiftSynapseUI` give you a complete chat interface, and **App Intents** integration enables Siri and Shortcuts support. On iOS 26+ / macOS 26+, agents run **on-device first** via Apple's Foundation Models framework with transparent cloud fallback.

This project follows a strict **spec-driven development (SDD)** workflow: every `.swift` file is a generated artifact. Human authors write and refine Markdown specifications; Claude Code produces all implementation code from those specs. Generated files are never edited manually — to change behavior, update the spec and regenerate.

---

## Key Features

- **Agent Delegation** — agents are thin wrappers (~30-60 lines) over `SwiftOpenResponsesDSL.Agent`, which handles tool dispatch loops, parallel execution, conversation continuity, and transcript management
- **SwiftUI Components** — `TranscriptView`, `AgentStatusView`, `StreamingTextView`, `ToolCallDetailView`, and `AgentChatView` provide drop-in agent UIs via `SwiftSynapseUI`
- **Spec-Driven Development** — every agent is defined by a `SPEC.md`; all Swift code is generated from it, never hand-written
- **Observable Agents** — `@Observable` state exposes live transcript, tool calls, and reasoning steps directly to SwiftUI views via `ObservableTranscript`
- **On-Device Priority** — Apple Foundation Models framework used first on iOS 26+ / macOS 26+ for full privacy; transparent cloud fallback via `HybridLLMClient`
- **Skills Integration** — [agentskills.io](https://agentskills.io) standard supported natively via `SkillStore`, `SkillsAgent`, and `activate_skill` tool
- **Type-Safe Tools** — `@LLMTool` macros generate JSON schemas at compile time; no stringly-typed dispatch, no runtime schema errors
- **App Intents** — `AgentAppIntent` protocol exposes agents to Siri and Shortcuts with a single conformance
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

**4. Run the AgentDashboard app**

Select the `AgentDashboard` scheme in Xcode and run. Pick an agent from the sidebar, type a goal, and watch the transcript live.

**5. Or run an agent from the CLI**

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

**6. Or invoke an agent in code**

```swift
import SwiftSynapseHarness
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

**7. Or use SwiftSynapseUI for a complete chat interface**

```swift
import SwiftSynapseUI

struct ContentView: View {
    let agent: some ObservableAgent

    var body: some View {
        AgentChatView(agent: agent)
    }
}
```

---

## Agent Examples

SwiftSynapse ships 7 runnable agents today. Every agent is fully spec-driven — no hand-written implementation code.

### Runnable now

| Agent | Description | Key Patterns Demonstrated |
|---|---|---|
| [SimpleEcho](./Agents/SimpleEcho/) | Echoes a goal string back with a prefix — the minimal `@SpecDrivenAgent` reference | `@SpecDrivenAgent` macro, transcript, status lifecycle |
| [LLMChat](./Agents/LLMChat/) | Forwards a prompt to any Open Responses API-compatible endpoint and returns the reply | `Agent` delegation, `retryWithBackoff`, transcript sync |
| [LLMChatPersonas](./Agents/LLMChatPersonas/) | Two-step pipeline: plain LLM response followed by an optional persona rewrite | `Agent` conversation continuity via `lastResponseId`, two-call pipeline |
| [RetryingLLMChatAgent](./Agents/RetryingLLMChatAgent/) | LLM chat with exponential-backoff retry on transient failures | Shared `retryWithBackoff`, `Agent` delegation |
| [StreamingChatAgent](./Agents/StreamingChatAgent/) | Streams LLM responses token-by-token with real-time transcript updates | `Agent.stream()`, `ToolSessionEvent`, `setStreaming`/`appendDelta` lifecycle |
| [ToolUsingAgent](./Agents/ToolUsingAgent/) | Dispatches LLM-chosen tool calls for math and unit conversion | `AgentTool` registration, `Agent` handles tool dispatch loop |
| [SkillsEnabledAgent](./Agents/SkillsEnabledAgent/) | Discovers and activates agentskills.io skills from the filesystem | `SkillStore`, `SkillsAgent`, `activate_skill` tool, ~30 lines of domain logic |

### Showcase agents (in progress)

| Agent | Description | Key Patterns Demonstrated |
|---|---|---|
| PRReviewer | Analyzes GitHub PRs for style, performance, and security issues | Tool calling, structured patches, multi-phase review |
| TaskPlanner | Multi-phase productivity agent with sub-task tracking | Planning, verification, sub-agent orchestration |
| ResearchAssistant | Long-running research agent with session persistence | Memory, web tools, RAG, background continuation |

> New agents are bootstrapped from [Agents/TemplateAgent/specs/SPEC.md](./Agents/TemplateAgent/specs/SPEC.md). Copy it, fill in the spec, and run the generator.

---

## Architecture

### Agent Delegation Pattern

Every agent is a thin wrapper over `SwiftOpenResponsesDSL.Agent`:

```swift
import SwiftSynapseHarness

@SpecDrivenAgent
public actor MyAgent {
    private let config: AgentConfiguration

    public init(configuration: AgentConfiguration) throws {
        self.config = configuration
        _ = try configuration.buildLLMClient()  // fail-fast validation
    }

    public func execute(goal: String) async throws -> String {
        guard !goal.isEmpty else { throw MyAgentError.emptyGoal }
        _status = .running
        _transcript.reset()

        let client = try config.buildLLMClient()
        let agent = Agent(client: client, model: config.modelName)

        let result = try await agent.send(goal)
        _transcript.sync(from: await agent.transcript)
        _status = .completed(result)
        return result
    }
}
```

### With tools (~60 lines)

```swift
let agent = try Agent(client: client, model: config.modelName) {
    AgentTool(tool: calculateDef) { args in try calculate(args) }
    AgentTool(tool: convertDef)   { args in try convert(args) }
}
let result = try await agent.send(goal)
// Agent handles the entire tool dispatch loop internally
```

### With skills (~30 lines)

```swift
let store = SkillStore()
try await store.load()
let agent = try await SkillsAgent(client: client, model: config.modelName) {
    Skills(store: store)
}
let result = try await agent.send(goal)
```

### Shared Types

| Type | Purpose |
|---|---|
| `AgentConfiguration` | Centralized config — validates URLs, model names, timeouts, retry counts. `fromEnvironment()` reads `SWIFTSYNAPSE_*` env vars. |
| `retryWithBackoff` | Free async function — exponential backoff with `isTransportRetryable` predicate and `onRetry` callback |
| `AgentLLMClient` | Protocol — `send(_:)` / `stream(_:)` with `CloudLLMClient` and `HybridLLMClient` (on-device + cloud fallback) implementations |
| `AgentSession` | Codable struct — session persistence with `CodableTranscriptEntry` bridge |

### Agent Harness (via SwiftSynapseHarness)

The [SwiftSynapseHarness](https://github.com/RichNasz/SwiftSynapseHarness) package provides a complete agent harness — everything between `run(goal:)` and your domain logic:

| Capability | Key Types |
|---|---|
| **Typed Tools** | `AgentToolProtocol`, `ToolRegistry`, `AgentToolLoop` — JSON-schema tools with batch dispatch |
| **Hooks** | `AgentHookPipeline`, `ClosureHook` — 15 event types with block/modify/proceed semantics |
| **Permissions** | `PermissionGate`, `ToolListPolicy` — policy-driven tool access with human-in-the-loop |
| **Recovery** | `RecoveryChain` — self-healing from context overflow and output truncation |
| **Streaming** | `StreamingToolExecutor` — dispatch tools as they stream from the LLM |
| **Subagents** | `SubagentRunner` — child agents with shared or independent lifecycles |
| **Session Persistence** | `FileSessionStore` — pause/resume workflows across app launches |
| **Guardrails** | `GuardrailPipeline`, `ContentFilter` — PII/secret detection, compliance checks |
| **MCP** | `MCPManager` — connect to Model Context Protocol servers (databases, CRMs, APIs) |
| **Coordination** | `CoordinationRunner` — dependency-aware multi-agent workflows |
| **Plugins** | `PluginManager` — modular extension mechanism for hooks, tools, guardrails |
| **Caching** | `ToolResultCache` — LRU/FIFO with TTL for identical tool calls |
| **Compression** | `CompositeCompressor` — advanced context window management |
| **Config Hierarchy** | `ConfigurationResolver` — 7-level priority (CLI > local > project > user > MDM > remote > env) |
| **Telemetry** | `TelemetrySink` — structured events to OSLog, in-memory, or custom backends |

### SwiftSynapseUI Components

| View | Purpose |
|---|---|
| `AgentChatView` | Complete drop-in chat UI: text input + transcript + status |
| `TranscriptView` | Chat-style message list with auto-scroll and streaming support |
| `AgentStatusView` | Status icon + label (idle/running/completed/error) |
| `StreamingTextView` | Typing cursor animation during token-by-token streaming |
| `ToolCallDetailView` | Expandable tool call row with JSON arguments, result, and duration |

### Protocols

| Protocol | Purpose |
|---|---|
| `ObservableAgent` | Common interface for all agents: `status`, `transcript`, `execute(goal:)` |
| `AgentAppIntent` | Exposes any `ObservableAgent` as a Siri Shortcut / Shortcuts action |

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
| `Apps/AgentDashboard/` | Example SwiftUI app | AI (never edit) |
| `README.md` | This file | AI (never edit) |

---

## Installation & Usage

SwiftSynapse agents depend on the macro libraries. Add them to your Swift package:

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/RichNasz/SwiftSynapseHarness", branch: "main"),
],
targets: [
    .target(
        name: "YourAgent",
        dependencies: [
            .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
        ]
    )
]
```

For SwiftUI views and App Intents:

```swift
.target(
    name: "YourApp",
    dependencies: [
        .product(name: "SwiftSynapseUI", package: "SwiftSynapseHarness"),
    ]
)
```

> `SwiftSynapseHarness` re-exports `SwiftOpenResponsesDSL`, `SwiftLLMToolMacros`, and `SwiftOpenSkills`, so a single import is all most agent files need.

> **Platform requirement:** On-device Foundation Models inference requires **iOS 26+**, **macOS 26+**, or **visionOS 2.4+** with Apple Intelligence enabled. For broader compatibility, point `AgentConfiguration` at any OpenAI-compatible cloud endpoint.

---

## Contributing

We welcome contributions — especially new agent specs, improvements to shared CodeGenSpecs, and infrastructure feedback.

### Adding a new agent

1. Copy `Agents/TemplateAgent/` -> `Agents/<YourAgentName>/`
2. Fill in `Agents/<YourAgentName>/specs/SPEC.md`
3. Customize `Agents/<YourAgentName>/specs/Overview.md` — delegate to `Agent` from SwiftOpenResponsesDSL, use `AgentConfiguration` and `retryWithBackoff`
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
| [SwiftSynapseHarness](https://github.com/RichNasz/SwiftSynapseHarness) | Unified agent harness — re-exports all dependencies; provides `@SpecDrivenAgent`, typed tools, hooks, permissions, recovery, streaming, MCP, guardrails, multi-agent coordination, session persistence, caching, plugins, telemetry, cost tracking, context management, `SwiftSynapseUI` |
| [SwiftOpenResponsesDSL](https://github.com/RichNasz/SwiftOpenResponsesDSL) | Base LLM communication layer — `Agent`, `ResponseRequest`, `LLMClient`, `AgentTool`, `ToolSession` |
| [SwiftLLMToolMacros](https://github.com/RichNasz/SwiftLLMToolMacros) | Tool definition macros — `@LLMTool` / `@LLMToolArguments` generate `FunctionToolParam` schemas |
| [SwiftOpenSkills](https://github.com/RichNasz/SwiftOpenSkills) | agentskills.io standard in Swift — `SkillStore`, `SkillsAgent`, skill discovery and activation |

Follow along: [@naszcyniec](https://x.com/naszcyniec) on X

---

<!-- Generated from CodeGenSpecs/README-Generation.md – Do not edit manually. Update spec and re-generate. -->
