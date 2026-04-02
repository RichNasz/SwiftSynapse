<!-- Generated from CodeGenSpecs/Agent-README-Generation.md + Agents/TaskPlanner/specs/SPEC.md — Do not edit manually. -->

# TaskPlanner

Decompose a complex goal into dependent phases, delegate each to a specialized subagent, track costs and tokens across the full run, and synthesize results into a unified plan.

## Overview

TaskPlanner is the reference implementation for the MultiAgent trait and Observability trait in SwiftSynapse. It demonstrates multi-agent orchestration with dependency-aware execution, shared state via `TeamMemory` and `SharedMailbox`, cost tracking via `CostTracker`, and full telemetry. The pattern matches CrewAI crews, AutoGen group chat, and LangGraph branching workflows. Independent phases run in parallel while dependent phases wait for their prerequisites.

**Patterns used:** CoordinationRunner, SubagentRunner, SharedMailbox, TeamMemory, CostTracker, TokenUsageTracker, CompositeTelemetrySink, SystemPromptBuilder, ConfigurationResolver.

**Platforms:** iOS 26+, macOS 26+, visionOS 2.4+

## Quick Start

**CLI:**

```bash
swift run task-planner "Plan our team's Q3 product launch including timeline, milestones, risks, and resource allocation" \
    --server-url http://127.0.0.1:1234/v1/responses \
    --model llama3
```

**Programmatic:**

```swift
import TaskPlannerAgent

let agent = try TaskPlanner(
    configuration: AgentConfiguration(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "llama3"
    )
)
let plan = try await agent.execute(goal: "Plan Q3 product launch")
print(plan)
```

**SwiftUI:**

```swift
struct MyView: View {
    @State private var agent = TaskPlanner()

    var body: some View {
        // agent.status and agent.transcript update automatically
    }
}
```

## Input

| Parameter | Type | Description |
|-----------|------|-------------|
| `goal` | `String` | Complex goal to decompose and execute (e.g., "Plan our team's Q3 product launch including timeline, milestones, risks, and resource allocation") |

## Output

| Field | Type | Description |
|-------|------|-------------|
| result | `String` | Unified Markdown plan combining all phase outputs with timeline, risks, and resource allocation |

## Tools

| Tool | Description | Concurrency Safe |
|------|-------------|-------------------|
| `breakdownGoal` | Decomposes a goal into phases with dependency graph | Yes |
| `prioritizeTasks` | Assigns priority scores and determines execution order | Yes |
| `synthesizeResults` | Combines phase outputs into a unified Markdown plan | Yes |

All tools are pure functions with no side effects.

## How It Works

1. Validate `goal` is non-empty; throw `TaskPlannerError.emptyGoal` if empty.
2. Set status to running and append user message to transcript.
3. Configure `CompositeTelemetrySink` with `OSLogTelemetrySink` and `CostTrackingTelemetrySink`.
4. Configure `AgentHookPipeline` with coordination and lifecycle hooks.
5. Build system prompt via `SystemPromptBuilder` with role, strategy, tools, and format sections.
6. Register 3 tools in `ToolRegistry`.
7. Run initial `AgentToolLoop.run()` where the LLM calls `breakdownGoal` to decompose the goal into phases.
8. Call `prioritizeTasks` to determine execution order.
9. Build `CoordinationPhase` array from breakdown results; independent phases run in parallel, dependent phases wait.
10. Create `SharedMailbox` and `TeamMemory` for inter-phase communication.
11. Run `CoordinationRunner.run(phases)` which fires phase hooks and executes subagents.
12. Collect `CoordinationResult` and log cost and token summaries.
13. Call `synthesizeResults` to combine all phase outputs into a unified plan.
14. Append assistant message, set status to completed, and return the plan.

## Transcript Example

```
[user]       Plan Q3 product launch
[toolCall]   breakdownGoal({"goal": "Plan Q3 product launch"})
[toolResult] breakdownGoal → [{id: "research", ...}, {id: "timeline", deps: ["research"]}, ...] (1.2s)
[toolCall]   prioritizeTasks({"phases": "[...]"})
[toolResult] prioritizeTasks → [{id: "research", priority: 1}, ...] (0.5s)
    — coordinationPhaseStarted: "research" (parallel) —
    — coordinationPhaseStarted: "stakeholders" (parallel) —
    — coordinationPhaseCompleted: "research" (2.1s) —
    — coordinationPhaseCompleted: "stakeholders" (1.8s) —
    — coordinationPhaseStarted: "timeline" (depends on: research) —
    — coordinationPhaseCompleted: "timeline" (1.5s) —
    — All 5 phases completed. Total cost: $0.0423 —
[toolCall]   synthesizeResults({"phaseResults": "{...}"})
[toolResult] synthesizeResults → "# Q3 Product Launch Plan..." (0.3s)
[assistant]  # Q3 Product Launch Plan...
```

## Testing

```bash
swift test --filter TaskPlannerTests
```

- Empty goal throws `TaskPlannerError.emptyGoal`
- Goal decomposition produces phases with correct dependency graph
- Independent phases execute in parallel (measured by overlapping durations)
- Dependent phases wait for dependencies (measured by sequential timing)
- `CostTracker` reports aggregate cost across all subagent LLM calls
- `TokenUsageTracker` reports total input/output tokens
- `coordinationPhaseStarted`/`Completed` hooks fire for each phase
- Partial phase failure produces a plan with warnings (not a crash)
- `TeamMemory` values written by one subagent are readable by another

## Constraints

- Import `SwiftSynapseHarness`; no raw URLSession or OpenAI SDK.
- Independent phases must run in parallel (not serialized).
- Dependent phases must wait for all dependencies before starting.
- All subagents share the same `TelemetrySink` for unified cost tracking.
- `TeamMemory` is actor-isolated — safe for concurrent subagent access.
- Partial results must be synthesized even if some phases fail.

## File Structure

```
Agents/TaskPlanner/
├── README.md
├── specs/
│   ├── SPEC.md
│   └── Overview.md
├── Sources/
│   └── TaskPlanner.swift
├── CLI/
│   └── TaskPlannerCLI.swift
└── Tests/
    └── TaskPlannerTests.swift
```

## License

MIT License — see the root [LICENSE](../../LICENSE) for details.

## Related

- [specs/SPEC.md](specs/SPEC.md) — agent specification
- [specs/Overview.md](specs/Overview.md) — generation rules
- [Root README.md](../../README.md) — project overview
