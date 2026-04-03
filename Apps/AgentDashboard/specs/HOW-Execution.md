# HOW: Agent Execution

> Prescribes the exact execution flow, concurrency model, and cancellation behavior for `DashboardModel.sendGoal()` and related methods.

---

## `sendGoal()` — Step-by-Step

```
1. Trim goalText. If empty: set errorMessage = "Please enter a goal." and return.
2. Guard isRunning == false. Return immediately if already running.
3. Capture:
       let goal     = goalText.trimmingCharacters(in: .whitespacesAndNewlines)
       let agentID  = selectedAgent
4. Mutate state:
       goalText     = ""
       isRunning    = true
       errorMessage = nil
       currentStatus = .running
5. Assign currentTask = Task { @MainActor in ... } containing the switch below.
6. On task completion (any path): isRunning = false; currentTask = nil
```

---

## Agent Switch (inside `Task { @MainActor in ... }`)

The full `do/catch` block:

```swift
do {
    switch agentID {

    case .simpleEcho:
        let agent = SimpleEcho()
        currentTranscript = await agent.transcript   // ← assign BEFORE run()
        _ = try await agent.run(goal: goal)
        currentStatus = await agent.status

    case .llmChat:
        let config = try buildConfiguration()
        let agent  = try LLMChat(configuration: config)
        currentTranscript = await agent.transcript
        _ = try await agent.run(goal: goal)
        currentStatus = await agent.status

    case .llmChatPersonas:
        let config   = try buildConfiguration()
        let agent    = try LLMChatPersonas(configuration: config)
        let persona: String? = personaText.isEmpty ? nil : personaText
        currentTranscript = await agent.transcript
        _ = try await agent.runWithPersona(goal: goal, persona: persona)
        currentStatus = await agent.status

    case .retryingLLMChat:
        let config = try buildConfiguration()
        let agent  = try RetryingLLMChatAgent(configuration: config)
        currentTranscript = await agent.transcript
        _ = try await agent.run(goal: goal)
        currentStatus = await agent.status

    case .streamingChat:
        let config = try buildConfiguration()
        let agent  = try StreamingChatAgent(configuration: config)
        currentTranscript = await agent.transcript   // ← CRITICAL: BEFORE run() — streaming begins immediately
        _ = try await agent.run(goal: goal)
        currentStatus = await agent.status

    case .toolUsing:
        let config = try buildConfiguration()
        let agent  = try ToolUsingAgent(configuration: config)
        currentTranscript = await agent.transcript
        _ = try await agent.run(goal: goal)
        currentStatus = await agent.status

    case .skillsEnabled:
        let config = try buildConfiguration()
        let agent  = try SkillsEnabledAgent(configuration: config)
        currentTranscript = await agent.transcript
        _ = try await agent.run(goal: goal)
        currentStatus = await agent.status

    case .prReviewer:
        let config = try buildConfiguration()
        let agent  = try PRReviewer(configuration: config)
        currentTranscript = await agent.transcript
        _ = try await agent.run(goal: goal)
        currentStatus = await agent.status

    case .performanceOptimizer:
        let config = try buildConfiguration()
        let agent  = try PerformanceOptimizer(configuration: config)
        currentTranscript = await agent.transcript
        _ = try await agent.run(goal: goal)
        currentStatus = await agent.status

    case .researchAssistant:
        let config = try buildConfiguration()
        let agent  = try ResearchAssistant(configuration: config)
        currentTranscript = await agent.transcript
        _ = try await agent.run(goal: goal)
        currentStatus = await agent.status

    case .taskPlanner:
        let config = try buildConfiguration()
        let agent  = try TaskPlanner(configuration: config)
        currentTranscript = await agent.transcript
        _ = try await agent.run(goal: goal)
        currentStatus = await agent.status

    case .dataPipeline:
        let config = try buildConfiguration()
        let agent  = try DataPipelineAgent(configuration: config)
        currentTranscript = await agent.transcript
        _ = try await agent.run(goal: goal)
        currentStatus = await agent.status

    case .none:
        break
    }

} catch is CancellationError {
    currentStatus = .idle

} catch {
    currentStatus = .error(error)
    errorMessage  = error.localizedDescription
}
isRunning    = false
currentTask  = nil
```

---

## Why `currentTranscript` Must Be Assigned Before `run()`

`ObservableTranscript` is owned by the agent actor. The dashboard's `currentTranscript` property must hold the **same object instance** that the agent will mutate during execution. SwiftUI's `@Observable` machinery tracks which object a view depends on at render time.

- If assigned **before** `run()`: the view subscribes to the correct object before any mutations occur. Streaming tokens, tool call entries, and assistant messages all update the view in real time.
- If assigned **after** `run()`: for non-streaming agents, all entries are already appended before SwiftUI sees the new reference. For streaming agents, the race is worse — the view may never observe any token.

Apply this rule to **all** agents, not just streaming ones, for consistency.

---

## Cancellation Flow

```
User taps Stop button
    → GoalInputView calls onCancel
    → DashboardModel.cancelCurrentRun()
    → currentTask?.cancel()
    → Swift delivers CancellationError at the next await suspension in the Task
    → catch is CancellationError branch executes:
          currentStatus = .idle
          (isRunning and currentTask reset in the finally block)
```

No `Task.isCancelled` polling is needed in the dashboard. Agents handle their own cancellation internally (as specified in their individual specs). The dashboard only needs to cancel the outer task.

---

## `buildConfiguration()` Implementation

```swift
func buildConfiguration() throws -> AgentConfiguration {
    guard let url = URL(string: configServerURL), !configServerURL.isEmpty else {
        throw AgentConfigurationError.invalidServerURL
    }
    guard !configModelName.isEmpty else {
        throw AgentConfigurationError.missingModelName
    }
    return AgentConfiguration(
        serverURL: url,
        modelName: configModelName,
        apiKey: configAPIKey.isEmpty ? nil : configAPIKey
    )
}
```

Errors from `buildConfiguration()` are caught by the outer `catch` clause in `sendGoal()` and surface as `errorMessage`.

---

## State Invariants

| Invariant | Guarantee |
|-----------|-----------|
| `isRunning == true` only while `currentTask` is non-nil | Prevents concurrent runs |
| `currentStatus == .running` exactly when `isRunning == true` | Status mirrors execution state |
| `currentTranscript` is replaced only in `clearTranscript()` or before `run()` | Transcript reference is stable during a run |
| Agent instances are never stored on `DashboardModel` | No actor isolation issues; fresh state each run |
| All state mutations happen inside `Task { @MainActor in ... }` | Zero data races |
