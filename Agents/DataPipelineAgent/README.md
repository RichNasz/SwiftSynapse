<!-- Generated from CodeGenSpecs/Agent-README-Generation.md + Agents/DataPipelineAgent/specs/SPEC.md — Do not edit manually. -->

# DataPipelineAgent

Process data through configurable pipelines using a plugin architecture where each data source and transformation self-registers tools, hooks, and prompt sections.

## Overview

DataPipelineAgent is the reference implementation for the Plugins trait in SwiftSynapse. It demonstrates modular, extensible data processing where capabilities are added without modifying agent code. Each plugin registers its own tools, hooks, guardrails, and system prompt sections via `PluginContext`. Three built-in plugins are provided: CSVPlugin, JSONPlugin, and MarkdownReportPlugin. The pattern matches LangGraph composable nodes and Agency Swarm extensible capabilities.

**Patterns used:** PluginManager, PluginContext, AgentPlugin protocol, SystemPromptBuilder, InMemoryTelemetrySink.

**Platforms:** iOS 26+, macOS 26+, visionOS 2.4+

## Quick Start

**CLI:**

```bash
swift run data-pipeline-agent "Analyze sales.csv and generate a quarterly report" \
    --server-url http://127.0.0.1:1234/v1/responses \
    --model llama3
```

**Programmatic:**

```swift
import DataPipelineAgentAgent

let agent = try DataPipelineAgent(
    configuration: AgentConfiguration(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "llama3"
    ),
    plugins: [CSVPlugin(), JSONPlugin(), MarkdownReportPlugin()]
)
let report = try await agent.execute(goal: "Analyze sales.csv and generate a quarterly report")
print(report)
```

**SwiftUI:**

```swift
struct MyView: View {
    @State private var agent = DataPipelineAgent()

    var body: some View {
        // agent.status and agent.transcript update automatically
    }
}
```

## Input

| Parameter | Type | Description |
|-----------|------|-------------|
| `goal` | `String` | Data processing request (e.g., "Analyze sales.csv and generate a quarterly report") |

## Output

| Field | Type | Description |
|-------|------|-------------|
| result | `String` | Processed data output or formatted report, depending on the plugins activated and goal |

## Tools

Tools are registered dynamically by plugins. The built-in plugins provide:

**CSVPlugin:**

| Tool | Description | Concurrency Safe |
|------|-------------|-------------------|
| `readCSV` | Reads a CSV file and returns JSON array of rows | Yes |
| `filterCSV` | Filters CSV data by column and predicate | Yes |
| `aggregateCSV` | Aggregates a column (sum/avg/count/min/max) | Yes |

**JSONPlugin:**

| Tool | Description | Concurrency Safe |
|------|-------------|-------------------|
| `queryJSON` | Extracts values using JSONPath expressions | Yes |
| `transformJSON` | Transforms JSON data using a mapping | Yes |

**MarkdownReportPlugin:**

| Tool | Description | Concurrency Safe |
|------|-------------|-------------------|
| `generateReport` | Produces a formatted Markdown report from title and sections | Yes |

All built-in plugin tools are pure functions with no side effects (except `readCSV` which reads from the filesystem).

## How It Works

1. Validate `goal` is non-empty; throw `DataPipelineAgentError.emptyGoal` if empty.
2. Set status to running and append user message to transcript.
3. Create `PluginContext` with `toolRegistry`, `hookPipeline`, `guardrailPipeline`, and `configResolver`.
4. Activate all plugins via `pluginManager.activateAll(context:)`. On plugin activation failure, emit `pluginError` telemetry and continue with remaining plugins.
5. Build system prompt via `SystemPromptBuilder` including plugin-contributed tool descriptions.
6. Run `AgentToolLoop.run()` with the `ToolRegistry` (now populated by plugins).
7. Guard non-empty result, append assistant message, set status to completed.
8. Deactivate all plugins via `pluginManager.deactivateAll()`.
9. Return result.

## Transcript Example

```
    — pluginActivated: "CSV" —
    — pluginActivated: "JSON" —
    — pluginActivated: "MarkdownReport" —
[user]       Analyze sales.csv and generate a quarterly report
[toolCall]   readCSV({"filePath": "sales.csv"})
[toolResult] readCSV → [{"month": "Jan", "revenue": 50000}, ...] (0.1s)
[toolCall]   aggregateCSV({"column": "revenue", "operation": "sum"})
[toolResult] aggregateCSV → 150000 (0.01s)
[toolCall]   aggregateCSV({"column": "revenue", "operation": "avg"})
[toolResult] aggregateCSV → 50000 (0.01s)
[toolCall]   generateReport({"title": "Q1 Sales Report", ...})
[toolResult] generateReport → "# Q1 Sales Report..." (0.05s)
[assistant]  # Q1 Sales Report\n\n## Summary\nTotal revenue: $150,000...
```

## Testing

```bash
swift test --filter DataPipelineAgentTests
```

- Empty goal throws `DataPipelineAgentError.emptyGoal`
- Plugins self-register tools — `toolRegistry.toolNames` includes plugin tools after activation
- Plugin activation failure is non-fatal — remaining plugins activate and agent runs
- Zero plugins activated throws `DataPipelineAgentError.noPluginsActivated`
- `pluginActivated` telemetry events fire for each activated plugin
- `pluginError` telemetry events fire for failed plugins
- Plugin-registered hooks fire during tool dispatch
- `SystemPromptBuilder` includes plugin-contributed tool descriptions
- Plugin deactivation occurs on both success and error paths

## Constraints

- Import `SwiftSynapseHarness`; no raw URLSession or OpenAI SDK.
- Plugins must self-register all tools — the agent does not hardcode any tool registrations.
- Plugin activation failures must not prevent the agent from running (degrade gracefully).
- At least one plugin must activate successfully — throw `noPluginsActivated` if all fail.
- Plugins must be `Sendable` and their activation must be safe for concurrent execution.
- Plugin deactivation must occur even if `execute()` throws (use defer).

## File Structure

```
Agents/DataPipelineAgent/
├── README.md
├── specs/
│   ├── SPEC.md
│   └── Overview.md
├── Sources/
│   └── DataPipelineAgent.swift
├── CLI/
│   └── DataPipelineAgentCLI.swift
└── Tests/
    └── DataPipelineAgentTests.swift
```

## License

MIT License — see the root [LICENSE](../../LICENSE) for details.

## Related

- [specs/SPEC.md](specs/SPEC.md) — agent specification
- [specs/Overview.md](specs/Overview.md) — generation rules
- [Root README.md](../../README.md) — project overview
