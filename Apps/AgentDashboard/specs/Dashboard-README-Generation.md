# Code Generation Spec: AgentDashboard README.md

## Purpose

Generate `Apps/AgentDashboard/README.md` — the reference document for the AgentDashboard SwiftUI app. Derived from the four dashboard spec files: `WHAT-App.md`, `WHAT-Agents.md`, `HOW-Architecture.md`, and `HOW-Views.md`.

---

## Target Audience

- Developers running the dashboard for the first time
- Contributors extending the dashboard with new agents
- Developers understanding the HIG patterns used

---

## Tone & Style

- Professional and practical — this is a developer tool, not a marketing page
- Concise and scannable: headings, tables, bullet lists, code blocks
- First-person plural ("we") for project voice; third-person for the app ("the dashboard")
- No emojis

---

## Required Sections (in exact order)

### 1. Header

Generated-file comment:
```
<!-- Generated from Apps/AgentDashboard/specs/Dashboard-README-Generation.md — Do not edit manually. Update spec and re-generate. -->
```

Title: `# AgentDashboard`

One-line description: *Native multi-platform SwiftUI dashboard for exploring and interacting with all 12 SwiftSynapse agents.*

---

### 2. Overview

3–5 sentences covering:
- What the dashboard is and what it does (interactive agent explorer, live transcript, LLM config)
- Platforms and Swift version
- Apple HIG compliance (NavigationSplitView, ContentUnavailableView, Dynamic Type, VoiceOver)
- That it is a generated artifact — do not edit `AgentDashboardApp.swift` directly; update the specs and regenerate

---

### 3. Features

Bullet list of user-visible features drawn from `WHAT-App.md`:
- Sidebar with Foundation and Advanced agent tiers
- Per-agent detail view with live transcript
- Streaming token display while response is in-flight
- Tool call and reasoning entries visible in transcript
- Stop button to cancel a running agent
- Error banner with Dismiss and Retry affordances
- Configuration sheet for LLM endpoint, model name, and API key (persisted to UserDefaults)
- Persona input field for LLM Chat Personas agent
- Auto-scrolling transcript

---

### 4. Agent Catalog

Two tables drawn from `WHAT-Agents.md`:

**Foundation Agents**

| Agent | Description | Requires LLM |
|-------|-------------|--------------|
| Simple Echo | Echoes input back — no LLM needed | No |
| LLM Chat | Single LLM call with retry | Yes |
| LLM Chat Personas | Two-step pipeline with optional persona rewrite | Yes |
| Retrying LLM Chat | LLM chat with exponential-backoff retry and transcript annotations | Yes |
| Streaming Chat | Token-by-token streaming response | Yes |
| Tool Using | Math and unit conversion via LLM tool dispatch | Yes |
| Skills Enabled | agentskills.io integration with skill discovery | Yes |

**Advanced Agents**

| Agent | Description | Harness Traits |
|-------|-------------|---------------|
| PR Reviewer | Code review with guardrails, permissions, and human-in-the-loop | Safety |
| Performance Optimizer | Performance analysis with recovery chains and rate limiting | Resilience |
| Research Assistant | Long-running research with session persistence and MCP | Persistence, MCP |
| Task Planner | Multi-agent coordination with cost tracking and telemetry | MultiAgent, Observability |
| Data Pipeline | Extensible data processing via plugin architecture | Plugins |

---

### 5. Running the Dashboard

The dashboard is a native SwiftUI app. The Xcode project is committed directly to the repository — no code generation step is required.

**Open in Xcode:**
```bash
open Apps/AgentDashboard/AgentDashboard.xcodeproj
```

Or double-click `Apps/AgentDashboard/AgentDashboard.xcodeproj` in Finder.

Describe destination selection: My Mac, iPhone Simulator, or Apple Vision Pro. Mention default window sizes (1100×720 on macOS, 900×680 on visionOS).

---

### 6. Configuration

Explain the configuration sheet:
- Open via the gear icon in the sidebar toolbar
- Three settings: Server URL, Model name, API key
- Defaults: `http://localhost:1234`, `lmstudio-community/qwen3-8b`, (empty)
- Values persisted to `UserDefaults.standard` under keys `dashboard.serverURL`, `dashboard.modelName`, `dashboard.apiKey`
- "Restore Defaults" button resets all three fields

Include a note: Simple Echo does not require any LLM configuration. All other agents require a valid Server URL and Model name.

---

### 7. Apple Human Interface Guidelines Compliance

Bullet list of the specific HIG requirements met, drawn from `WHAT-App.md`:
- `NavigationSplitView` for sidebar+detail layout
- `ContentUnavailableView` for empty transcript and no-selection states
- System semantic colors only (no hardcoded values)
- Dynamic Type support via default `.font` modifiers
- VoiceOver: `accessibilityLabel` and `accessibilityHint` on all interactive elements
- macOS keyboard shortcut: `⌘↩` to Send/Stop
- `Form`-based configuration sheet
- Platform-appropriate toolbar placements

---

### 8. Architecture

Brief architecture description drawn from `HOW-Architecture.md`:

- **`DashboardModel`** — `@MainActor @Observable final class` that owns all runtime state. Passed by reference into child views. No stored agent instances — agents are created fresh per run and released on completion.
- **`AgentID`** — 12-case enum (`CaseIterable`, `Identifiable`) with computed `tier`, `displayName`, `systemImage`, `requiresLLM` properties
- **`AgentTier`** — `.foundation` / `.advanced` used to section the sidebar list
- **Views** — 10 SwiftUI structs following HIG conventions; `TranscriptView`, `AgentStatusView`, and `StreamingTextView` imported from `SwiftSynapseUI`

Include a short concurrency note: all agent runs execute in a `Task { @MainActor in ... }`. Agent `transcript` is assigned to `DashboardModel.currentTranscript` before `run()` is called, ensuring the `@Observable` reference is established before any entries arrive.

---

### 9. Regenerating the Dashboard

```
# Edit the spec files in Apps/AgentDashboard/specs/, then re-prompt:
#   "Regenerate Apps/AgentDashboard/AgentDashboardApp.swift from its specs"
```

State which files are the source of truth (all four WHAT/HOW specs) and which is the generated artifact (`AgentDashboardApp.swift`). Do not edit the generated file directly.

---

### 10. File Structure

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
    └── Dashboard-README-Generation.md     ← this generation spec
```

---

### 11. License

Single line: "MIT License — see the root [LICENSE](../../LICENSE) for details."

---

### 12. Related

Links to:
- `specs/WHAT-App.md` — app requirements and HIG compliance rules
- `specs/WHAT-Agents.md` — agent catalog
- `specs/HOW-Architecture.md` — implementation architecture
- Root `README.md` — project overview
- [SwiftSynapseHarness](https://github.com/RichNasz/SwiftSynapseHarness) — harness dependency

---

## Constraints

- All content must trace to the WHAT/HOW spec files — do not invent features
- Include the generated-file header comment at the very top
- GitHub-flavored Markdown only; no YAML front-matter
- Target length: 150–250 lines

---

## Output Instructions

Generate the complete `Apps/AgentDashboard/README.md` content now.
