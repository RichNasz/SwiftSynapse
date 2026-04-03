# HOW: Architecture

> Prescribes the implementation structure for AgentDashboardApp.swift — generated file layout, type design, import list, UserDefaults keys, and Swift 6.2 concurrency rules.

---

## Generated File

| Property | Value |
|----------|-------|
| Path | `Apps/AgentDashboard/AgentDashboardApp.swift` |
| Action | Full rewrite on every codegen run |
| Header (line 1) | `// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.` |
| CLI target | None |
| Test target | None |

---

## Import List

```swift
// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import SwiftUI
import Foundation
import SwiftSynapseHarness
import SwiftSynapseUI
import SimpleEchoAgent
import LLMChatAgent
import LLMChatPersonasAgent
import RetryingLLMChatAgentAgent
import StreamingChatAgentAgent
import ToolUsingAgentAgent
import SkillsEnabledAgentAgent
import PRReviewerAgent
import PerformanceOptimizerAgent
import ResearchAssistantAgent
import TaskPlannerAgent
import DataPipelineAgentAgent
```

---

## Type Ordering

Use `// MARK: - <TypeName>` comment before each top-level declaration:

1. `AgentTier`
2. `AgentID`
3. `DashboardModel`
4. `AgentDashboardApp`
5. `DashboardView`
6. `SidebarView`
7. `AgentRowView`
8. `DetailView`
9. `AgentDetailView`
10. `ErrorBannerView`
11. `PersonaInputView`
12. `GoalInputView`
13. `ConfigurationSheet`

---

## `AgentTier` Enum

```swift
enum AgentTier: String, CaseIterable {
    case foundation = "Foundation"
    case advanced   = "Advanced"

    var displayName: String { rawValue }
}
```

---

## `AgentID` Enum

```swift
enum AgentID: String, CaseIterable, Identifiable, Hashable, Sendable {
    // Foundation tier
    case simpleEcho           = "SimpleEcho"
    case llmChat              = "LLMChat"
    case llmChatPersonas      = "LLMChatPersonas"
    case retryingLLMChat      = "RetryingLLMChatAgent"
    case streamingChat        = "StreamingChatAgent"
    case toolUsing            = "ToolUsingAgent"
    case skillsEnabled        = "SkillsEnabledAgent"
    // Advanced tier
    case prReviewer           = "PRReviewer"
    case performanceOptimizer = "PerformanceOptimizer"
    case researchAssistant    = "ResearchAssistant"
    case taskPlanner          = "TaskPlanner"
    case dataPipeline         = "DataPipelineAgent"

    var id: String { rawValue }
}
```

Computed properties on `AgentID` (all inline):

| Property | Type | Notes |
|----------|------|-------|
| `displayName` | `String` | Human-readable (e.g. `"Simple Echo"`, `"PR Reviewer"`) |
| `agentDescription` | `String` | One-line description matching WHAT-Agents.md |
| `systemImage` | `String` | SF Symbol name matching WHAT-Agents.md |
| `tier` | `AgentTier` | `.foundation` for first 7, `.advanced` for last 5 |
| `requiresLLM` | `Bool` | `false` only for `.simpleEcho` |

---

## `DashboardModel` Class

```swift
@MainActor
@Observable
final class DashboardModel {
    var selectedAgent: AgentID?            = .simpleEcho
    var goalText: String                   = ""
    var personaText: String                = ""
    var isRunning: Bool                    = false
    var currentTranscript: ObservableTranscript = ObservableTranscript()
    var currentStatus: AgentStatus         = .idle
    var errorMessage: String?              = nil
    var showingConfiguration: Bool         = false
    var configServerURL: String
    var configModelName: String
    var configAPIKey: String
    private var currentTask: Task<Void, Never>? = nil
```

### `init()`

Load from `UserDefaults.standard`. If a key is absent or empty, use the default:

| Key | Default |
|-----|---------|
| `"dashboard.serverURL"` | `"http://localhost:1234"` |
| `"dashboard.modelName"` | `"lmstudio-community/qwen3-8b"` |
| `"dashboard.apiKey"` | `""` |

### Methods

| Method | Behavior |
|--------|----------|
| `sendGoal()` | See HOW-Execution.md |
| `cancelCurrentRun()` | `currentTask?.cancel()`, `isRunning = false`, `currentStatus = .idle` |
| `clearTranscript()` | Replace `currentTranscript` with `ObservableTranscript()`, `currentStatus = .idle`, `errorMessage = nil` |
| `saveConfiguration()` | Write all three keys to `UserDefaults.standard`, set `showingConfiguration = false` |
| `buildConfiguration() throws -> AgentConfiguration` | Build from current `configServerURL`/`configModelName`/`configAPIKey`; throw `AgentConfigurationError` on invalid URL or empty model |
| `agentSelectionChanged()` | Call `clearTranscript()`, set `goalText = ""`, `personaText = ""` |

---

## Swift 6.2 Concurrency Rules

- `DashboardModel` is `@MainActor`-isolated. All property reads and writes within its own methods require no `await`.
- `sendGoal()` creates `currentTask = Task { @MainActor in ... }`. The explicit `@MainActor` annotation on the closure body makes all state mutations safe without extra `await`.
- Agent actors are created locally inside the Task closure. They are **never** stored on `DashboardModel`. They are created, used, and released within a single run.
- `currentTranscript = await agent.transcript` crosses an actor boundary — the `await` is required and correct.
- `currentStatus = await agent.status` — same pattern, required and correct.
- Do **not** use `nonisolated(unsafe)`, `@unchecked Sendable`, or `Task.detached`.

---

## UserDefaults Keys

Use `UserDefaults.standard` (not a custom app group suite). Exact key strings:

```
"dashboard.serverURL"
"dashboard.modelName"
"dashboard.apiKey"
```

Load in `init()`. Save in `saveConfiguration()`. Do **not** use `@AppStorage` — use explicit `UserDefaults` reads/writes.
