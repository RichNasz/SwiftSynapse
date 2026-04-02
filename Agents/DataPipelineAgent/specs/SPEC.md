# DataPipelineAgent Specification

> Reference implementation for Plugins trait — modular, extensible data processing where each data source and transformation is a plugin that self-registers tools, hooks, and prompt sections.

## Purpose

Process data through configurable pipelines (CSV analysis, JSON transformation, report generation) using a plugin architecture. Each plugin registers its own tools, hooks, guardrails, and system prompt sections via `PluginContext`. Demonstrates how to build extensible agents where capabilities are added without modifying agent code — matching LangGraph composable nodes and Agency Swarm extensible capabilities.

---

## Configuration

| Parameter       | Type                 | Default | Description |
|-----------------|----------------------|---------|-------------|
| `configuration` | `AgentConfiguration` | —       | Server URL, model, API key, timeout, retries |
| `plugins`       | `[any AgentPlugin]`  | `[]`    | Plugins to activate (CSV, JSON, Markdown, etc.) |

---

## Input

| Parameter | Type     | Description |
|-----------|----------|-------------|
| `goal`    | `String` | Data processing request (e.g., "Analyze sales.csv and generate a quarterly report") |

---

## Plugin Architecture

### Plugin Lifecycle

1. At init: register plugins with `PluginManager`.
2. Before `execute()`: activate all plugins via `pluginManager.activateAll(context:)`.
3. Each plugin's `activate(context:)` method:
   - Registers tools via `context.toolRegistry`
   - Registers hooks via `context.hookPipeline`
   - Registers guardrails via `context.guardrailPipeline` (optional)
   - Reads config via `context.configResolver`
4. After activation: build system prompt including plugin-contributed sections.
5. On shutdown: `pluginManager.deactivateAll()`.

### PluginContext

```swift
let context = PluginContext(
    toolRegistry: toolRegistry,
    hookPipeline: hookPipeline,
    guardrailPipeline: guardrailPipeline,
    configResolver: configResolver
)
```

### Built-in Plugins

#### CSVPlugin
```swift
struct CSVPlugin: AgentPlugin {
    let name = "CSV"
    let version = "1.0"

    func activate(context: PluginContext) async throws {
        await context.toolRegistry.register(ReadCSVTool())
        await context.toolRegistry.register(FilterCSVTool())
        await context.toolRegistry.register(AggregateCSVTool())
    }
    func deactivate() async { }
}
```

**Tools provided:**
- `readCSV` — Input: `filePath: String`. Output: JSON array of rows. `isConcurrencySafe: true`.
- `filterCSV` — Input: `data: String`, `column: String`, `predicate: String`. Output: filtered JSON. `isConcurrencySafe: true`.
- `aggregateCSV` — Input: `data: String`, `column: String`, `operation: String` (sum/avg/count/min/max). Output: aggregated value. `isConcurrencySafe: true`.

#### JSONPlugin
```swift
struct JSONPlugin: AgentPlugin {
    let name = "JSON"
    let version = "1.0"

    func activate(context: PluginContext) async throws {
        await context.toolRegistry.register(QueryJSONTool())
        await context.toolRegistry.register(TransformJSONTool())
    }
    func deactivate() async { }
}
```

**Tools provided:**
- `queryJSON` — Input: `data: String`, `path: String` (JSONPath expression). Output: extracted value. `isConcurrencySafe: true`.
- `transformJSON` — Input: `data: String`, `mapping: String`. Output: transformed JSON. `isConcurrencySafe: true`.

#### MarkdownReportPlugin
```swift
struct MarkdownReportPlugin: AgentPlugin {
    let name = "MarkdownReport"
    let version = "1.0"

    func activate(context: PluginContext) async throws {
        await context.toolRegistry.register(GenerateReportTool())
        // Add a hook that logs report generation
        await context.hookPipeline.add(ClosureHook(events: [.postToolUse]) { event in
            if case .postToolUse(let name, _) = event, name == "generateReport" {
                // Log report generation event
            }
            return .proceed
        })
    }
    func deactivate() async { }
}
```

**Tools provided:**
- `generateReport` — Input: `title: String`, `sections: String` (JSON). Output: Formatted Markdown report. `isConcurrencySafe: true`.

---

## SystemPromptBuilder Integration

After plugin activation, query the tool registry for available tools and build the system prompt:

```swift
var builder = SystemPromptBuilder()
builder.addSection("You are a data processing assistant...", priority: 100, label: "Role")

// Add plugin-contributed capabilities
let toolNames = toolRegistry.toolNames
builder.addSection("Available tools: \(toolNames.joined(separator: ", "))", priority: 50, label: "Tools")

// Each plugin can describe its capabilities
for plugin in pluginManager.activePluginNames {
    builder.addSection("Plugin '\(plugin)' provides data processing capabilities.", priority: 30, label: plugin)
}
```

---

## Observability

Uses `InMemoryTelemetrySink` for debug/test mode — collects all telemetry events in memory for assertions and inspection:

```swift
let sink = InMemoryTelemetrySink()
agent.configure(telemetry: sink)

// After run, inspect events:
let events = await sink.events
let pluginEvents = events.filter { $0.kind == .pluginActivated }
```

Telemetry emits `pluginActivated(name:)` for each successfully activated plugin, and `pluginError(name:error:)` for any activation failure.

---

## Tasks (execute steps)

1. Validate `goal` is non-empty. Set `_status = .error(DataPipelineAgentError.emptyGoal)` and throw if empty.
2. Set `_status = .running`. Append `.userMessage(goal)`.
3. Create `PluginContext` with `toolRegistry`, `hookPipeline`, `guardrailPipeline`, `configResolver`.
4. Activate all plugins via `pluginManager.activateAll(context:)`.
   - On plugin activation failure: emit `pluginError` telemetry, continue with remaining plugins.
5. Build system prompt via `SystemPromptBuilder` including plugin-contributed tool descriptions.
6. Run `AgentToolLoop.run()` with `toolRegistry` (now populated by plugins).
7. Guard non-empty result. Append `.assistantMessage(result)`. Set `_status = .completed(result)`.
8. Deactivate all plugins via `pluginManager.deactivateAll()`.
9. Return result.

---

## Errors

```swift
public enum DataPipelineAgentError: Error, Sendable {
    case emptyGoal
    case noResponseContent
    case noPluginsActivated
    case dataFileNotFound(path: String)
}
```

Plugin activation failures are non-fatal — the agent continues with whatever plugins activated successfully. If zero plugins activate, throw `noPluginsActivated`.

---

## Transcript Shape

```
[0] .userMessage("Analyze sales.csv and generate a quarterly report")
    — pluginActivated: "CSV" —
    — pluginActivated: "JSON" —
    — pluginActivated: "MarkdownReport" —
[1] .toolCall(name: "readCSV", arguments: "{\"filePath\": \"sales.csv\"}")
[2] .toolResult(name: "readCSV", result: "[{\"month\": \"Jan\", \"revenue\": 50000}, ...]")
[3] .toolCall(name: "aggregateCSV", arguments: "{\"column\": \"revenue\", \"operation\": \"sum\"}")
[4] .toolResult(name: "aggregateCSV", result: "150000")
[5] .toolCall(name: "aggregateCSV", arguments: "{\"column\": \"revenue\", \"operation\": \"avg\"}")
[6] .toolResult(name: "aggregateCSV", result: "50000")
[7] .toolCall(name: "generateReport", arguments: "{\"title\": \"Q1 Sales Report\", ...}")
[8] .toolResult(name: "generateReport", result: "# Q1 Sales Report\n...")
[9] .assistantMessage("# Q1 Sales Report\n\n## Summary\nTotal revenue: $150,000...")
```

---

## Hooks

Plugin-registered hooks fire alongside agent hooks. The `MarkdownReportPlugin` registers a `postToolUse` hook for report generation logging.

Agent-level hooks:
- `agentStarted` / `agentCompleted` — lifecycle tracking

---

## Constraints

- Import `SwiftSynapseHarness`; no raw URLSession or OpenAI SDK.
- Plugins must self-register all tools — the agent does not hardcode any tool registrations.
- Plugin activation failures must not prevent the agent from running (degrade gracefully).
- At least one plugin must activate successfully — throw `noPluginsActivated` if all fail.
- Plugins must be `Sendable` and their activation must be safe for concurrent execution.
- Plugin deactivation must occur even if `execute()` throws (use defer).

---

## Success Criteria

1. Empty goal throws `DataPipelineAgentError.emptyGoal`.
2. Plugins self-register tools — `toolRegistry.toolNames` includes plugin tools after activation.
3. Plugin activation failure is non-fatal — remaining plugins activate and agent runs.
4. Zero plugins activated throws `DataPipelineAgentError.noPluginsActivated`.
5. `pluginActivated` telemetry events fire for each activated plugin.
6. `pluginError` telemetry events fire for failed plugins.
7. Plugin-registered hooks fire during tool dispatch.
8. `SystemPromptBuilder` includes plugin-contributed tool descriptions.
9. Plugin deactivation occurs on both success and error paths.

---

## Platforms

iOS 26+, macOS 26+, visionOS 2.4+. Swift 6.2+ strict concurrency.
