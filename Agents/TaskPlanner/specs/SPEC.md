# TaskPlanner Agent Specification

> Reference implementation for MultiAgent trait and Observability trait — multi-agent coordination with dependency-aware execution, shared state, cost tracking, and full telemetry.

## Purpose

Accept a complex goal, decompose it into dependent phases, delegate each phase to a specialized subagent, track costs and token usage across the full run, and synthesize results into a unified plan. Demonstrates multi-agent orchestration that matches CrewAI crews, AutoGen group chat, and LangGraph branching workflows.

---

## Configuration

| Parameter       | Type                 | Default | Description |
|-----------------|----------------------|---------|-------------|
| `configuration` | `AgentConfiguration` | —       | Server URL, model, API key, timeout, retries |

Uses `ConfigurationResolver` with `EnvironmentConfigSource` + `FileConfigSource.projectDefault` for layered configuration resolution.

---

## Input

| Parameter | Type     | Description |
|-----------|----------|-------------|
| `goal`    | `String` | Complex goal to decompose and execute (e.g., "Plan our team's Q3 product launch including timeline, milestones, risks, and resource allocation") |

---

## Tools (3 tools)

### breakdownGoal
- **Input**: `goal: String`
- **Output**: JSON array of phases with dependencies: `[{id, name, description, dependencies: [phaseId]}]`
- **Side effects**: None
- **`isConcurrencySafe`**: `true`

### prioritizeTasks
- **Input**: `phases: String` (JSON array of phases)
- **Output**: JSON array with priority scores and execution order
- **Side effects**: None
- **`isConcurrencySafe`**: `true`

### synthesizeResults
- **Input**: `phaseResults: String` (JSON map of phase ID to result)
- **Output**: Unified Markdown plan combining all phase outputs
- **Side effects**: None
- **`isConcurrencySafe`**: `true`

---

## Multi-Agent Coordination

### Phase Decomposition

The LLM calls `breakdownGoal` to produce a dependency graph. Each phase becomes a `CoordinationPhase`:

```swift
let phases = breakdownResult.map { phase in
    CoordinationPhase(
        id: phase.id,
        agentType: LLMChat.self,    // subagent type for each phase
        goal: phase.description,
        dependencies: phase.dependencies
    )
}
```

Independent phases (no dependencies) run in parallel. Dependent phases wait for their dependencies to complete.

### SubagentRunner

Each phase is executed by a subagent via `SubagentRunner`:

```swift
let context = SubagentContext(
    configuration: config,
    toolRegistry: nil,              // subagents use their own tools
    hookPipeline: sharedHookPipeline,
    lifecycleMode: .shared          // cancelled if parent cancels
)
```

### CoordinationRunner

```swift
let result = try await CoordinationRunner.run(phases)
// result.phaseResults: [String: SubagentResult]
// result.totalDuration: Duration
// result.allSucceeded: Bool
```

Fires `coordinationPhaseStarted` and `coordinationPhaseCompleted` hooks for each phase.

### SharedMailbox

Phases can send messages to other phases:

```swift
let mailbox = SharedMailbox()
// Phase "research" sends findings to phase "analysis":
await mailbox.send("Key finding: ...", from: "research", to: "analysis")
```

### TeamMemory

Shared key-value store accessible by all subagents:

```swift
let teamMemory = TeamMemory()
await teamMemory["timeline"] = "Q3 2026: July-September"
// Other subagents read:
let timeline = await teamMemory["timeline"]
```

---

## Observability & Cost Tracking

### TelemetrySink Configuration

```swift
let costTracker = CostTracker()
await costTracker.setPricing(for: config.modelName, pricing: ModelPricing(
    inputCostPerMillionTokens: 3.00,
    outputCostPerMillionTokens: 15.00
))

let telemetrySink = CompositeTelemetrySink([
    OSLogTelemetrySink(),
    CostTrackingTelemetrySink(tracker: costTracker),
])
```

Each subagent receives the same `CompositeTelemetrySink`, so all LLM calls across all phases accumulate in a single `CostTracker`.

### TokenUsageTracker

```swift
let tokenTracker = TokenUsageTracker()
// After each subagent completes:
await tokenTracker.record(inputTokens: result.inputTokens, outputTokens: result.outputTokens)
```

### Post-Run Summary

After coordination completes, emit a summary:
```
Total cost: $0.0423
Total tokens: 14,230 input / 3,891 output
Phases completed: 5/5
Total duration: 12.3s
```

---

## SystemPromptBuilder

Build the parent agent's system prompt with prioritized sections:

```swift
var builder = SystemPromptBuilder()
builder.addSection("You are a task planning coordinator...", priority: 100, label: "Role")
builder.addSection("Break complex goals into phases with dependencies...", priority: 80, label: "Strategy")
builder.addSection("Available tools: breakdownGoal, prioritizeTasks, synthesizeResults", priority: 50, label: "Tools")
builder.addSection("Output format: structured plan with timeline and risks", priority: 30, label: "Format")
```

---

## Configuration Hierarchy

Uses `ConfigurationResolver` for multi-source configuration:

```swift
let resolver = ConfigurationResolver([
    EnvironmentConfigSource(),                    // SWIFTSYNAPSE_* env vars
    FileConfigSource.projectDefault,              // .swiftsynapse/config.json
])
```

This demonstrates the 7-level priority system where project-level config overrides environment variables but CLI arguments override both.

---

## Tasks (execute steps)

1. Validate `goal` is non-empty. Set `_status = .error(TaskPlannerError.emptyGoal)` and throw if empty.
2. Set `_status = .running`. Append `.userMessage(goal)`.
3. Configure `CompositeTelemetrySink` with `OSLogTelemetrySink` + `CostTrackingTelemetrySink`.
4. Configure `AgentHookPipeline` with coordination and lifecycle hooks.
5. Build system prompt via `SystemPromptBuilder`.
6. Register 3 tools in `ToolRegistry`.
7. Run initial `AgentToolLoop.run()` — LLM calls `breakdownGoal` to decompose the goal into phases.
8. Call `prioritizeTasks` to determine execution order.
9. Build `CoordinationPhase` array from breakdown results.
10. Create `SharedMailbox` and `TeamMemory`.
11. Run `CoordinationRunner.run(phases)` — fires phase hooks, executes subagents.
12. Collect `CoordinationResult`. Log cost and token summaries.
13. Call `synthesizeResults` to combine phase outputs into a unified plan.
14. Append `.assistantMessage(plan)`. Set `_status = .completed(plan)`. Return.

---

## Errors

```swift
public enum TaskPlannerError: Error, Sendable {
    case emptyGoal
    case noResponseContent
    case phaseDecompositionFailed
    case coordinationFailed(phaseId: String, error: Error)
    case synthesisFailedNoResults
}
```

Individual phase failures are captured in `CoordinationResult` — if `allSucceeded` is false, the planner can still synthesize partial results with warnings.

---

## Transcript Shape

```
[0] .userMessage("Plan Q3 product launch")
[1] .toolCall(name: "breakdownGoal", ...)
[2] .toolResult(name: "breakdownGoal", result: "[{id: 'research', ...}, {id: 'timeline', deps: ['research']}, ...]")
[3] .toolCall(name: "prioritizeTasks", ...)
[4] .toolResult(name: "prioritizeTasks", result: "[...]")
[5] .reasoning("Executing 5 phases via CoordinationRunner...")
    — coordinationPhaseStarted: "research" (parallel) —
    — coordinationPhaseStarted: "stakeholders" (parallel) —
    — coordinationPhaseCompleted: "research" (2.1s) —
    — coordinationPhaseCompleted: "stakeholders" (1.8s) —
    — coordinationPhaseStarted: "timeline" (depends on: research) —
    — coordinationPhaseCompleted: "timeline" (1.5s) —
    — coordinationPhaseStarted: "risks" (depends on: research, timeline) —
    — coordinationPhaseStarted: "resources" (depends on: stakeholders) —
    — coordinationPhaseCompleted: "risks" (1.2s) —
    — coordinationPhaseCompleted: "resources" (0.9s) —
[6] .reasoning("All 5 phases completed. Total cost: $0.0423")
[7] .toolCall(name: "synthesizeResults", ...)
[8] .toolResult(name: "synthesizeResults", result: "# Q3 Product Launch Plan\n...")
[9] .assistantMessage("# Q3 Product Launch Plan\n## Timeline\n...")
```

---

## Hooks

Subscribes to:
- `agentStarted` / `agentCompleted` / `agentFailed` — parent agent lifecycle
- `coordinationPhaseStarted` / `coordinationPhaseCompleted` — phase execution tracking
- `preToolUse` / `postToolUse` — tool dispatch logging
- `transcriptUpdated` — live transcript monitoring

---

## Constraints

- Import `SwiftSynapseHarness`; no raw URLSession or OpenAI SDK.
- Independent phases must run in parallel (not serialized).
- Dependent phases must wait for all dependencies before starting.
- All subagents share the same `TelemetrySink` for unified cost tracking.
- `TeamMemory` is actor-isolated — safe for concurrent subagent access.
- Partial results must be synthesized even if some phases fail.

---

## Success Criteria

1. Empty goal throws `TaskPlannerError.emptyGoal`.
2. Goal decomposition produces phases with correct dependency graph.
3. Independent phases execute in parallel (measured by overlapping durations).
4. Dependent phases wait for dependencies (measured by sequential timing).
5. `CostTracker` reports aggregate cost across all subagent LLM calls.
6. `TokenUsageTracker` reports total input/output tokens.
7. `coordinationPhaseStarted`/`Completed` hooks fire for each phase.
8. Partial phase failure produces a plan with warnings (not a crash).
9. `TeamMemory` values written by one subagent are readable by another.

---

## Platforms

iOS 26+, macOS 26+, visionOS 2.4+. Swift 6.2+ strict concurrency.
