# Shared Spec: Multi-Agent Coordination

> MultiAgent trait — subagent spawning, coordination phases, and shared state.

---

## Summary

Multi-agent coordination enables complex workflows where multiple agents collaborate. A parent agent can spawn subagents, coordinate execution order via dependency graphs, and share state through mailboxes and team memory.

---

## Subagent Spawning

### SubagentContext

```swift
public struct SubagentContext: Sendable {
    public let configuration: AgentConfiguration
    public let toolRegistry: ToolRegistry?
    public let hookPipeline: AgentHookPipeline?
    public let lifecycleMode: SubagentLifecycleMode
}
```

### SubagentLifecycleMode

```swift
public enum SubagentLifecycleMode: Sendable {
    case independent    // subagent manages its own lifecycle
    case shared         // subagent shares parent's lifecycle (cancelled if parent cancels)
}
```

### SubagentResult

```swift
public struct SubagentResult: Sendable {
    public let output: String
    public let transcript: [TranscriptEntry]
    public let duration: Duration
    public let success: Bool
}
```

### SubagentRunner

```swift
public enum SubagentRunner {
    public static func run<A: AgentExecutable>(
        _ agentType: A.Type,
        goal: String,
        context: SubagentContext
    ) async throws -> SubagentResult

    public static func runParallel<A: AgentExecutable>(
        _ tasks: [(agentType: A.Type, goal: String)],
        context: SubagentContext
    ) async throws -> [SubagentResult]
}
```

---

## Coordination

### CoordinationPhase

```swift
public struct CoordinationPhase<A: AgentExecutable>: Sendable {
    public let id: String
    public let agentType: A.Type
    public let goal: String
    public let dependencies: [String]    // phase IDs that must complete first
}
```

### CoordinationRunner

```swift
public enum CoordinationRunner {
    public static func run(_ phases: [any CoordinationPhaseProtocol]) async throws -> CoordinationResult
}
```

Executes phases in dependency order (DAG). Independent phases run in parallel. Dependent phases wait for their dependencies to complete.

### CoordinationResult

```swift
public struct CoordinationResult: Sendable {
    public let phaseResults: [String: SubagentResult]
    public let totalDuration: Duration
    public let allSucceeded: Bool
}
```

---

## Shared State

### SharedMailbox

```swift
public actor SharedMailbox {
    public func send(_ message: String, from: String, to: String)
    public func receive(for agentId: String) async -> [String]
}
```

Cross-agent message passing for loosely-coupled communication.

### TeamMemory

```swift
public actor TeamMemory {
    public subscript(key: String) -> String? { get set }
}
```

Shared key-value store accessible by all agents in a coordination run.

---

## Integration Points

- **Hooks**: fires `coordinationPhaseStarted` / `coordinationPhaseCompleted` events
- **Telemetry**: each subagent emits its own telemetry events
- **Session Persistence**: subagent sessions are independent of parent
- If the MultiAgent trait is disabled, coordination types compile to stubs that throw.
