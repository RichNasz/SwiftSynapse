# WHAT: AgentDashboard App

> Describes what the AgentDashboard app does — its purpose, user-visible features, HIG requirements, and success criteria. Does not prescribe implementation.

---

## Goal

A native multi-platform SwiftUI application that lets a developer interactively run any of the 12 SwiftSynapse agents, observe live transcripts (streaming tokens, tool calls, reasoning steps), and configure the LLM endpoint — following Apple Human Interface Guidelines throughout.

---

## User-Visible Features

- **Agent Sidebar** — lists all agents grouped into Foundation and Advanced tiers
- **Agent Selection** — choosing an agent clears the previous transcript and shows that agent's detail view
- **Goal Input** — a text input bar for entering a goal and sending it to the selected agent
- **Live Transcript** — updates as the agent appends entries (user messages, assistant messages, tool calls, tool results, reasoning)
- **Streaming Display** — shows tokens as they arrive while a response is in-flight
- **Error Banner** — appears on agent failure with Dismiss and Retry affordances
- **Cancel Affordance** — a Stop button aborts a running agent mid-execution
- **Configuration Sheet** — a settings panel for the LLM server URL, model name, and optional API key
- **Persistent Configuration** — configuration values survive app restarts
- **Persona Field** — a persona input shown exclusively for the LLM Chat Personas agent

---

## Apple Human Interface Guidelines Compliance

All of the following are required — not optional:

- Use `NavigationSplitView` for the sidebar+detail layout (not custom drawers or sheets)
- Use `ContentUnavailableView` for all empty states: no agent selected, empty transcript
- Use only system semantic colors: `.accent`, `.primary`, `.secondary`, `.red` — no hardcoded hex, RGB, or UIColor literals
- Support Dynamic Type: all text uses default `.font` modifiers (no fixed point sizes anywhere)
- VoiceOver accessibility: every interactive element has `.accessibilityLabel` and `.accessibilityHint`
- macOS keyboard navigation: `⌘↩` shortcut triggers the Send/Stop action; standard tab and focus ring behavior throughout
- Use `Form` for the configuration/settings sheet (provides native platform appearance on all targets)
- Place toolbar items in platform-appropriate positions: `.principal` for the status view, `.navigationBarTrailing` (or `.automatic`) for action buttons
- VoiceOver traversal order must match the visual top-to-bottom layout; no custom priority overrides
- Platform-native input controls: `.keyboardType(.URL)` on the server URL field (iOS), `SecureField` for the API key

---

## Platforms

iOS 26+, macOS 26+, visionOS 2+. Swift 6.2+ strict concurrency. No minimum deployment target lower than these.

---

## Success Criteria

- [ ] All 12 agents appear in the sidebar under correct tier sections (7 Foundation, 5 Advanced)
- [ ] Selecting an agent clears the transcript and resets status to `.idle`
- [ ] Simple Echo runs without any LLM configuration and produces no error banner
- [ ] Streaming Chat shows a live token display while `isStreaming == true`
- [ ] Tool Using shows `.toolCall` and `.toolResult` entries visible in the transcript
- [ ] LLM Chat Personas shows the persona input field; all other agents do not
- [ ] Configuration sheet values persist to UserDefaults and reload correctly after app restart
- [ ] Cancelling a running agent sets status to `.idle` and `isRunning` to `false`
- [ ] Error banner appears on network/agent failure with both Dismiss and Retry buttons
- [ ] `ContentUnavailableView` renders for an empty transcript and when no agent is selected
- [ ] Compiles cleanly under Swift 6.2 strict concurrency with zero errors and zero warnings
- [ ] Accessibility Inspector (macOS) reports no unlabeled interactive elements
- [ ] Dynamic Type at the largest accessibility size produces no text truncation or clipping
