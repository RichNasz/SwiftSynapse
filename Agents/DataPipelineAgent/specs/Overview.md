# Code Generation Overview: DataPipelineAgent

> Instructs the code generator on what files to produce and how to assemble them from SPEC.md and shared CodeGenSpecs.

---

## Files to Generate

| File | Target | Purpose |
|------|--------|---------|
| `Sources/DataPipelineAgent.swift` | `DataPipelineAgentAgent` library | Main actor + error enum |
| `Sources/DataPipelineAgent+Plugins.swift` | `DataPipelineAgentAgent` library | Built-in plugin implementations (CSV, JSON, Markdown) |
| `CLI/DataPipelineAgentCLI.swift` | `data-pipeline-agent` executable | ArgumentParser CLI |
| `Tests/DataPipelineAgentTests.swift` | `DataPipelineAgentTests` test target | Swift Testing suite |

---

## Shared Types Used

- `AgentConfiguration` — centralized config
- `AgentPlugin` / `PluginManager` / `PluginContext` — plugin lifecycle
- `AgentToolProtocol` / `ToolRegistry` — typed tool registration (by plugins)
- `AgentToolLoop.run()` — tool dispatch loop
- `SystemPromptBuilder` — prompt composition with plugin-contributed sections
- `AgentHookPipeline` / `ClosureHook` — hooks registered by plugins
- `GuardrailPipeline` — guardrails registered by plugins (optional)
- `ConfigurationResolver` — config access for plugins
- `InMemoryTelemetrySink` — telemetry for test/debug mode
- `@SpecDrivenAgent` macro — generates observable state

---

## Shared Specs to Apply

1. `Shared-Configuration.md` — `AgentConfiguration` init
2. `Shared-Plugin-System.md` — `AgentPlugin`, `PluginManager`, `PluginContext`, lifecycle
3. `Shared-Agent-Tool-Loop.md` — `AgentToolLoop.run()` with plugin-registered tools
4. `Shared-System-Prompt-Builder.md` — prompt composition with plugin capabilities
5. `Shared-Hook-System.md` — plugin-registered hooks
6. `Shared-Telemetry.md` — `InMemoryTelemetrySink`, `pluginActivated`/`pluginError` events
7. `Shared-Tool-Registry.md` — `AgentToolProtocol` conformances (in plugins)
8. `Shared-Error-Strategy.md` — error enum, status-before-throw

---

## Actor State Properties

```swift
@SpecDrivenAgent
public actor DataPipelineAgent {
    private let config: AgentConfiguration
    private let pluginManager: PluginManager
    private let toolRegistry: ToolRegistry
    private let hookPipeline: AgentHookPipeline
    private let guardrailPipeline: GuardrailPipeline
}
```

---

## Init Rules

1. Primary init takes `AgentConfiguration` + `[any AgentPlugin]`.
2. Registers plugins with `PluginManager`.
3. Creates shared `ToolRegistry`, `AgentHookPipeline`, `GuardrailPipeline`.

---

## execute() Rules

1. Guard non-empty goal.
2. Build `PluginContext` and activate all plugins.
3. Build system prompt with plugin-contributed tool info.
4. Run tool loop with plugin-populated registry.
5. Deactivate plugins in defer block.
6. Return result.

---

## CLI Rules

Uses `AgentConfiguration.fromEnvironment(overrides:)`. Plugins are hardcoded to built-in set (CSV, JSON, Markdown). Includes `--data-file` option.

---

## Test Rules

1. `dataPipelineThrowsOnEmptyGoal` — empty goal error
2. `dataPipelinePluginsSelfRegisterTools` — tool names include plugin tools
3. `dataPipelinePluginActivationFailureGraceful` — bad plugin skipped, others work
4. `dataPipelineNoPluginsThrows` — zero plugins → `noPluginsActivated`
5. `dataPipelinePluginTelemetryFires` — `pluginActivated` events emitted
6. `dataPipelinePluginErrorTelemetryFires` — `pluginError` for failed plugins
7. `dataPipelinePluginHooksFire` — plugin-registered hooks fire during dispatch
8. `dataPipelineSystemPromptIncludesPlugins` — prompt contains plugin tool descriptions
9. `dataPipelinePluginDeactivationOnError` — deactivation runs even on throw
