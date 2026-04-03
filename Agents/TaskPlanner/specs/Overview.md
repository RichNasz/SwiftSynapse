# Code Generation Overview: TaskPlanner

> Instructs the code generator on what files to produce and how to assemble them from SPEC.md and shared CodeGenSpecs.

---

## Files to Generate

| File | Target | Purpose |
|------|--------|---------|
| `Sources/TaskPlanner.swift` | `TaskPlannerAgent` library | Error enum + tool structs + agent actor |
| `CLI/TaskPlannerCLI.swift` | `task-planner` executable | ArgumentParser CLI |
| `Tests/TaskPlannerTests.swift` | `TaskPlannerTests` test target | Swift Testing suite |

All tool structs live in `Sources/TaskPlanner.swift` above the agent actor, separated by `// MARK: - Tool Definitions`.

---

## Shared Types Used

- `AgentConfiguration` — centralized config
- `ConfigurationResolver` / `EnvironmentConfigSource` / `FileConfigSource` — layered config hierarchy
- `@LLMTool` / `@LLMToolArguments` / `@LLMToolGuide` — macro stack for compile-time tool schema generation
- `AgentLLMTool` — protocol bridging `LLMTool` and `AgentToolProtocol`; only `call(arguments:) -> ToolOutput` required
- `ToolRegistry` — registers `AgentLLMTool` conformances and dispatches calls
- `AgentToolLoop.run()` — tool dispatch loop
- `CoordinationRunner` / `CoordinationPhase` / `CoordinationResult` — DAG-based phase execution
- `SubagentRunner` / `SubagentContext` / `SubagentLifecycleMode` / `SubagentResult` — subagent spawning
- `SharedMailbox` — cross-agent messaging
- `TeamMemory` — shared key-value store
- `TelemetrySink` / `OSLogTelemetrySink` / `CompositeTelemetrySink` — telemetry
- `CostTracker` / `CostTrackingTelemetrySink` / `ModelPricing` — cost tracking
- `TokenUsageTracker` — token accounting
- `SystemPromptBuilder` — prioritized prompt composition
- `AgentHookPipeline` / `ClosureHook` — lifecycle and coordination hooks
- `@SpecDrivenAgent` macro — generates observable state

---

## Shared Specs to Apply

1. `Shared-Configuration.md` — `AgentConfiguration` init
2. `Shared-Configuration-Hierarchy.md` — `ConfigurationResolver` with multi-source resolution
3. `Shared-Multi-Agent-Coordination.md` — `CoordinationRunner`, `SubagentRunner`, `SharedMailbox`, `TeamMemory`
4. `Shared-Cost-Tracking.md` — `CostTracker`, `ModelPricing`, `CostTrackingTelemetrySink`
5. `Shared-Telemetry.md` — `TelemetrySink`, `OSLogTelemetrySink`, `CompositeTelemetrySink`, `TokenUsageTracker`
6. `Shared-System-Prompt-Builder.md` — prioritized prompt composition
7. `Shared-Agent-Tool-Loop.md` — `AgentToolLoop.run()`
8. `Shared-Hook-System.md` — coordination phase hooks, lifecycle hooks
9. `Shared-Tool-Registry.md` — `AgentLLMTool` conformances
10. `Shared-Error-Strategy.md` — error enum, status-before-throw

---

## Actor State Properties

```swift
@SpecDrivenAgent
public actor TaskPlanner {
    private let config: AgentConfiguration
    private let costTracker: CostTracker
    private let tokenTracker: TokenUsageTracker
    private let hookPipeline: AgentHookPipeline
    private let toolRegistry: ToolRegistry
    private let teamMemory: TeamMemory
    private let mailbox: SharedMailbox
}
```

---

## Init Rules

1. Primary init takes `AgentConfiguration`.
2. Resolves config via `ConfigurationResolver` if `FileConfigSource.projectDefault` exists.
3. Configures `CostTracker` with model pricing.
4. Sets up `CompositeTelemetrySink`.

---

## execute() Rules

1. Guard non-empty goal.
2. Decompose goal via `breakdownGoal` tool.
3. Prioritize phases via `prioritizeTasks` tool.
4. Build `CoordinationPhase` array with dependencies.
5. Run `CoordinationRunner.run(phases)`.
6. Log cost/token summary.
7. Synthesize results via `synthesizeResults` tool.
8. Return unified plan.

---

## CLI Rules

Uses `AgentConfiguration.fromEnvironment(overrides:)`. Supports `--config-file` for project-level config. Prints cost summary after completion.

---

## Test Rules

1. `taskPlannerThrowsOnEmptyGoal` — empty goal error
2. `taskPlannerDecomposesGoal` — breakdown produces phases with dependencies
3. `taskPlannerParallelPhases` — independent phases overlap in time
4. `taskPlannerSequentialDependencies` — dependent phases wait correctly
5. `taskPlannerCostTracking` — CostTracker reports aggregate cost
6. `taskPlannerTokenTracking` — TokenUsageTracker counts all calls
7. `taskPlannerCoordinationHooksFire` — phase start/complete hooks fire
8. `taskPlannerPartialFailure` — partial results synthesized with warnings
9. `taskPlannerTeamMemoryShared` — values readable across subagents
