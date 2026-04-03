<!-- Generated from Apps/AgentDashboard/specs/Dashboard-README-Generation.md — Do not edit manually. Update spec and re-generate. -->

# AgentDashboard

Native multi-platform SwiftUI dashboard for exploring and interacting with all 12 SwiftSynapse agents.

---

## Overview

AgentDashboard is the interactive front-end for the SwiftSynapse showcase repository. It provides a live, observable window into every agent — from the no-LLM `SimpleEcho` proof-of-concept through the advanced `TaskPlanner` multi-agent coordinator — letting you send goals, watch transcripts update in real time, and inspect tool calls, streaming tokens, and reasoning steps as they arrive.

The dashboard targets iOS 26+, macOS 26+, and visionOS 2+, built with Swift 6.2 strict concurrency. It is designed to comply with Apple Human Interface Guidelines throughout: `NavigationSplitView` for layout, `ContentUnavailableView` for empty states, system semantic colors, Dynamic Type, and full VoiceOver support.

`AgentDashboardApp.swift` is a generated artifact. Do not edit it directly — update the specs in `Apps/AgentDashboard/specs/` and regenerate.

---

## Features

- Sidebar listing all 12 agents grouped into **Foundation** and **Advanced** tier sections
- Per-agent detail view with live, auto-scrolling transcript
- Streaming token display while a response is in-flight
- Tool call and reasoning entries rendered in the transcript via `TranscriptView`
- **Stop button** to cancel a running agent at any time
- Error banner with **Dismiss** and **Retry** affordances on agent failure
- Configuration sheet for LLM endpoint, model name, and API key (persisted across launches)
- Persona input field shown exclusively for the LLM Chat Personas agent
- Empty-state views for no agent selected and no transcript activity

---

## Agent Catalog

### Foundation Agents

| Agent | Description | Requires LLM |
|-------|-------------|:------------:|
| Simple Echo | Echoes input back — no LLM needed | No |
| LLM Chat | Single LLM call with retry | Yes |
| LLM Chat Personas | Two-step pipeline with optional persona rewrite | Yes |
| Retrying LLM Chat | LLM chat with exponential-backoff retry and transcript annotations | Yes |
| Streaming Chat | Token-by-token streaming response | Yes |
| Tool Using | Math and unit conversion via LLM tool dispatch | Yes |
| Skills Enabled | agentskills.io integration with skill discovery | Yes |

### Advanced Agents

| Agent | Description | Harness Traits |
|-------|-------------|---------------|
| PR Reviewer | Code review with guardrails, permissions, and human-in-the-loop | Safety |
| Performance Optimizer | Performance analysis with recovery chains and rate limiting | Resilience |
| Research Assistant | Long-running research with session persistence and MCP | Persistence, MCP |
| Task Planner | Multi-agent coordination with cost tracking and telemetry | MultiAgent, Observability |
| Data Pipeline | Extensible data processing via plugin architecture | Plugins |

---

## Running the Dashboard

The dashboard is a native SwiftUI app. The Xcode project (`AgentDashboard.xcodeproj`) is committed directly to the repository — no code generation step is required.

**Open and run in Xcode:**

```bash
open Apps/AgentDashboard/AgentDashboard.xcodeproj
# Select AgentDashboard scheme + destination (My Mac, iPhone Simulator, Vision Pro), then Run
```

Or double-click `Apps/AgentDashboard/AgentDashboard.xcodeproj` in Finder to open it.

Default window sizes: **1100×720** on macOS, **900×680** on visionOS.

---

## Configuration

Open the configuration sheet via the **gear icon** in the sidebar toolbar.

| Setting | Default | UserDefaults Key |
|---------|---------|-----------------|
| Server URL | `http://localhost:1234` | `dashboard.serverURL` |
| Model name | `lmstudio-community/qwen3-8b` | `dashboard.modelName` |
| API key | *(empty)* | `dashboard.apiKey` |

Values are persisted to `UserDefaults.standard` when you tap **Save & Close**. **Restore Defaults** resets all three fields in-sheet without saving until you confirm.

> **Note:** Simple Echo requires no LLM configuration — it runs entirely on-device. All other agents require a valid Server URL and Model name before a run can start.

---

## Apple Human Interface Guidelines Compliance

The dashboard is built to HIG standards:

- `NavigationSplitView` for sidebar+detail layout — no custom drawers
- `ContentUnavailableView` for all empty states (no selection, no transcript activity)
- System semantic colors exclusively: `.accent`, `.primary`, `.secondary`, `.red` — no hardcoded values
- Dynamic Type: all text uses default `.font` modifiers with no fixed point sizes
- VoiceOver: `.accessibilityLabel` and `.accessibilityHint` on every interactive element (sidebar rows, toolbar buttons, input fields, error banner actions)
- macOS keyboard shortcut: **⌘↩** to Send or Stop
- `Form`-based configuration sheet for native platform appearance
- Toolbar items in platform-appropriate placements (`.principal` for status, `.automatic` for actions)

---

## Architecture

**`DashboardModel`** is a `@MainActor @Observable final class` that owns all runtime state:

```swift
var selectedAgent: AgentID?
var goalText: String
var currentTranscript: ObservableTranscript
var currentStatus: AgentStatus
var isRunning: Bool
var errorMessage: String?
// ...
```

Agent instances are created fresh inside `Task { @MainActor in ... }` on each run and released on completion — they are never stored on the model. This eliminates cross-actor state issues and gives each run a clean slate.

**Transcript assignment rule:** `currentTranscript = await agent.transcript` is assigned *before* `agent.run(goal:)` is called for every agent. This ensures the shared `@Observable` reference is established before any entries arrive — critical for streaming agents that begin appending tokens immediately on `run()`.

**Cancellation:** the Stop button calls `cancelCurrentRun()` which invokes `currentTask?.cancel()`. Swift delivers `CancellationError` at the next `await` suspension inside the task; the `catch is CancellationError` clause resets `currentStatus` to `.idle`.

**View hierarchy:**

```
AgentDashboardApp
└── DashboardView
    ├── SidebarView
    │   └── AgentRowView (×12)
    └── DetailView
        └── AgentDetailView
            ├── TranscriptView          ← from SwiftSynapseUI
            ├── StreamingTextView       ← from SwiftSynapseUI
            ├── AgentStatusView         ← from SwiftSynapseUI
            ├── ErrorBannerView
            ├── PersonaInputView        ← LLMChatPersonas only
            └── GoalInputView
```

---

## Regenerating the Dashboard

The spec files are the source of truth. To update the dashboard:

1. Edit one or more files in `Apps/AgentDashboard/specs/`
2. Regenerate `AgentDashboardApp.swift` by prompting:
   > *"Regenerate `Apps/AgentDashboard/AgentDashboardApp.swift` from its specs"*

Never edit `AgentDashboardApp.swift` directly — changes will be overwritten on the next generation.

---

## File Structure

```
Apps/AgentDashboard/
├── README.md                              ← this file (generated)
├── AgentDashboardApp.swift                ← generated; do not edit manually
├── AgentDashboard.xcodeproj/              ← committed Xcode project; open to build and run
└── specs/
    ├── WHAT-App.md                        ← goal, features, HIG requirements, success criteria
    ├── WHAT-Agents.md                     ← agent catalog, tiers, calling conventions
    ├── HOW-Architecture.md                ← DashboardModel, type ordering, concurrency rules
    ├── HOW-Views.md                       ← exact view structure, accessibility, platform guards
    ├── HOW-Execution.md                   ← sendGoal() steps, agent switch, cancellation
    └── Dashboard-README-Generation.md     ← README generation spec
```

---

## License

MIT License — see the root [LICENSE](../../LICENSE) for details.

---

## Related

- [`specs/WHAT-App.md`](specs/WHAT-App.md) — app requirements and HIG compliance rules
- [`specs/WHAT-Agents.md`](specs/WHAT-Agents.md) — full agent catalog
- [`specs/HOW-Architecture.md`](specs/HOW-Architecture.md) — implementation architecture
- [Root README](../../README.md) — SwiftSynapse project overview
- [SwiftSynapseHarness](https://github.com/RichNasz/SwiftSynapseHarness) — harness dependency
