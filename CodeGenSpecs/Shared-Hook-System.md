# Shared Spec: Hook System

> Hooks trait — intercept and modify agent behavior at 16 lifecycle points.

---

## Summary

The hook system allows agents to observe and control execution flow without modifying agent logic. Hooks can log, audit, gate, or transform operations at every significant lifecycle point.

---

## Core Types

### AgentHook Protocol

```swift
public protocol AgentHook: Sendable {
    var subscribedEvents: Set<AgentHookEventKind> { get }
    func handle(_ event: AgentHookEvent) async -> HookAction
}
```

Hooks declare which events they care about via `subscribedEvents`. The pipeline only invokes a hook for events it subscribes to.

### HookAction

```swift
public enum HookAction: Sendable {
    case proceed                    // continue normally
    case modify(String)             // replace content (e.g., modified prompt)
    case block(reason: String)      // halt the operation
}
```

Not all events support all actions. Events like `agentStarted` are informational — only `.proceed` is meaningful. Events like `preToolUse` and `llmRequestSent` support `.block` and `.modify`.

### AgentHookEventKind (16 Events)

```swift
public enum AgentHookEventKind: Sendable, Hashable {
    case agentStarted
    case agentCompleted
    case agentFailed
    case agentCancelled
    case preToolUse                 // before tool dispatch — can block
    case postToolUse                // after tool dispatch
    case llmRequestSent             // before LLM call — can modify prompt
    case llmResponseReceived        // after LLM response
    case transcriptUpdated          // transcript entry appended
    case sessionSaved
    case sessionRestored
    case guardrailTriggered         // guardrail policy activated
    case coordinationPhaseStarted
    case coordinationPhaseCompleted
    case memoryUpdated
    case transcriptRepaired         // integrity violation repaired
}
```

### AgentHookPipeline

```swift
public actor AgentHookPipeline {
    public func add(_ hook: any AgentHook)
    public func fire(_ event: AgentHookEvent) async -> HookAction
}
```

The pipeline evaluates hooks in registration order. If any hook returns `.block`, the pipeline short-circuits. If any returns `.modify`, the modified value propagates to subsequent hooks.

### ClosureHook

```swift
public struct ClosureHook: AgentHook {
    public init(
        events: Set<AgentHookEventKind>,
        handler: @Sendable @escaping (AgentHookEvent) async -> HookAction
    )
}
```

Convenience type for inline hook definitions without creating a dedicated type.

---

## Usage Pattern

```swift
let pipeline = AgentHookPipeline()

// Logging hook — observe all events
await pipeline.add(ClosureHook(events: [.agentStarted, .agentCompleted, .agentFailed]) { event in
    print("Hook: \(event)")
    return .proceed
})

// Approval gate — block specific tools
await pipeline.add(ClosureHook(events: [.preToolUse]) { event in
    if case .preToolUse(let toolName, _) = event, toolName == "deleteFile" {
        return .block(reason: "deleteFile requires manual approval")
    }
    return .proceed
})
```

---

## Integration Points

- **AgentToolLoop**: fires `preToolUse` / `postToolUse` around each tool dispatch
- **LLM calls**: fires `llmRequestSent` / `llmResponseReceived` around inference
- **Transcript**: fires `transcriptUpdated` on every append
- **Session persistence**: fires `sessionSaved` / `sessionRestored`
- **Guardrails**: fires `guardrailTriggered` when a policy activates
- **Coordination**: fires phase start/complete events during multi-agent runs
- **Telemetry**: hook events can trigger telemetry emission

---

## Rules

- Hooks must be `Sendable` — they execute in the pipeline actor's isolation.
- Hook handlers should be fast — long-running hooks delay the agent pipeline.
- If the Hooks trait is disabled, hooks compile to no-op stubs (always `.proceed`).
- The `@SpecDrivenAgent` macro does not generate hook infrastructure; agents that use hooks create and manage their own `AgentHookPipeline`.
