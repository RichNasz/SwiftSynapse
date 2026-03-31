# Shared Spec: Background Execution

> Defines how every SwiftSynapse agent continues processing when the host app is backgrounded.

---

## Summary

Agents that may run longer than a few seconds must register a `BGContinuedProcessingTask` (BackgroundTasks framework, iOS 16+/macOS 13+). The agent's main `Task` is started inside the background task handler and cancelled via `task.expirationHandler` if the system reclaims time. All agent work is expressed as `async` functions so cancellation propagates cleanly through Swift concurrency's cooperative cancellation model.

Agents must checkpoint their progress to allow resumption after expiration. The shared checkpoint and resume contract is defined in `Shared-Session-Resume.md`. This document covers the `BGContinuedProcessingTask` integration, cooperative cancellation, and checkpoint frequency.

---

## BGContinuedProcessingTask Integration

Agents that support background execution register their work with the BackgroundTasks framework. The pattern is:

```swift
import BackgroundTasks

// In the host app's setup (AppDelegate or @main App body):
BGTaskScheduler.shared.register(
    forTaskWithIdentifier: "com.yourapp.agent.longrunning",
    using: nil
) { task in
    guard let bgTask = task as? BGContinuedProcessingTask else { return }

    let runningTask = Task {
        let agent = try LongRunningAgent(configuration: config)
        _ = try await agent.execute(goal: savedGoal)
    }

    bgTask.expirationHandler = {
        runningTask.cancel()
    }

    Task {
        _ = try? await runningTask.value
        bgTask.setTaskCompleted(success: !runningTask.isCancelled)
    }
}
```

The agent itself does not reference `BGContinuedProcessingTask` directly. The agent is a pure `actor` with cooperative cancellation. The host app integrates it with the background task system.

---

## Cooperative Cancellation

Agents check `Task.isCancelled` at step boundaries — between each LLM call, between each tool call, and between major phases. The check pattern is:

```swift
// At the start of each step
try Task.checkCancellation()

// Or equivalently, before each await point in a multi-step loop
guard !Task.isCancelled else {
    _status = .paused
    throw CancellationError()
}
```

Rules:
- `Task.checkCancellation()` is called **before** each `_llmClient.send()` call.
- `Task.checkCancellation()` is called **before** each `ToolExecutor.execute()` call.
- `Task.checkCancellation()` is called at the top of each iteration of the tool dispatch loop.
- When cancellation is detected, set `_status = .paused` (not `.error`) before throwing `CancellationError()`.
- `CancellationError` propagates to the host app. The host app decides whether to save the session.

---

## Checkpoint Frequency

Agents checkpoint after each logical step that represents durable progress:

| Event | Checkpoint? |
|-------|-------------|
| After successful LLM response | Yes |
| After each tool call completes | Yes |
| After appending a user message | No (trivial, reconstructible) |
| After setting `_status = .running` | No |
| During streaming (mid-response) | No |

Checkpointing means calling `currentSession()` and signaling the host app. Agents do not write to disk themselves — they expose `currentSession()` and the host app persists it:

```swift
// In agent execute() after a checkpoint moment:
NotificationCenter.default.post(
    name: .agentDidCheckpoint,
    object: await currentSession()
)
// Or: call a provided callback/delegate
```

If the spec for a particular agent defines a custom checkpoint callback, that is specified in that agent's `Overview.md`.

---

## Checkpoint Data Structure

All background-capable agents conform to the `AgentSession` model defined in `Shared-Session-Resume.md`. The `customState: Data?` field holds agent-specific state that is not captured by the transcript alone.

For agents with no custom state (all state is in the transcript), `customState` is `nil`.

For agents with custom state (e.g., an intermediate result used only if the next step fails), encode it as JSON:

```swift
struct MyCustomState: Codable {
    let intermediateResult: String
    let phaseName: String
}

// In currentSession():
let custom = MyCustomState(intermediateResult: _lastPartialResult, phaseName: "phase2")
let customData = try? JSONEncoder().encode(custom)
```

---

## Resumption

When the host app calls `resume(from:)`, the agent:

1. Validates the session type matches.
2. Restores `_transcript` from `session.transcriptEntries`.
3. Decodes `session.customState` if present.
4. Calls the internal `execute(goal:resumingFrom:)` overload, which skips steps `0..<session.completedStepIndex`.

From the host app's perspective, `resume(from:)` and `execute(goal:)` have the same return type and error behavior — the caller does not need to know which path was taken.

---

## Background Execution Platforms

- **iOS 16+ / macOS 13+**: `BGContinuedProcessingTask` is the integration point.
- **visionOS 2+**: Same BackgroundTasks framework is available.
- **Older platform versions**: Background execution is not supported. Agents must check availability at runtime or limit this capability to the minimum deployment targets specified in each agent's spec.
