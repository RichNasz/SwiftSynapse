# Shared Spec: Plugin System

> Plugins trait — modular extension mechanism for agent capabilities.

---

## Summary

Plugins provide a structured way to extend agent functionality without modifying agent code. A plugin can register tools, hooks, guardrails, and configuration at activation time. Plugins follow a lifecycle (activate/deactivate) managed by the `PluginManager`.

---

## Core Types

### AgentPlugin Protocol

```swift
public protocol AgentPlugin: Sendable {
    var name: String { get }
    var version: String { get }
    func activate(context: PluginContext) async throws
    func deactivate() async
}
```

### PluginContext

```swift
public struct PluginContext: Sendable {
    public let toolRegistry: ToolRegistry
    public let hookPipeline: AgentHookPipeline
    public let guardrailPipeline: GuardrailPipeline
    public let configResolver: ConfigurationResolver
}
```

Provides access to framework registries so plugins can register their own tools, hooks, guardrails, and read configuration.

### PluginManager

```swift
public actor PluginManager {
    public func register(_ plugin: any AgentPlugin)
    public func activateAll(context: PluginContext) async throws
    public func deactivate(_ name: String) async
    public func deactivateAll() async
    public func isActive(_ name: String) -> Bool
    public var registeredPlugins: [any AgentPlugin] { get }
    public var activePluginNames: [String] { get }
}
```

---

## Usage Pattern

```swift
struct LoggingPlugin: AgentPlugin {
    let name = "Logging"
    let version = "1.0"

    func activate(context: PluginContext) async throws {
        await context.hookPipeline.add(ClosureHook(events: [.agentStarted, .agentCompleted]) { event in
            print("[LoggingPlugin] \(event)")
            return .proceed
        })
    }

    func deactivate() async { }
}

let manager = PluginManager()
await manager.register(LoggingPlugin())
await manager.activateAll(context: pluginContext)
```

---

## Integration Points

- **Telemetry**: emits `.pluginActivated(name:)` and `.pluginError(name:error:)` events
- **Hooks**: plugins register hooks via `PluginContext.hookPipeline`
- **Tools**: plugins register tools via `PluginContext.toolRegistry`
- **Guardrails**: plugins register policies via `PluginContext.guardrailPipeline`
- If the Plugins trait is disabled, plugin operations compile to no-op stubs.
