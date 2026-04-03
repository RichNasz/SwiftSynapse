# Shared Spec: Tool Registry

> Defines how LLM tools are defined, registered, and dispatched across all SwiftSynapse agents using SwiftLLMToolMacros.

---

## Summary

Tools are defined as Swift structs conforming to `AgentLLMTool`, decorated with `@LLMTool` from `SwiftLLMToolMacros`. The macro synthesizes `name` (snake_case of struct name), `description` (from the doc comment), and `toolDefinition: ToolDefinition`. No JSON schema is written by hand. Tools are registered in a `ToolRegistry` and dispatched automatically by `AgentToolLoop`.

---

## Tool definition

```swift
/// Fetch the current weather for a location.
@LLMTool
public struct GetCurrentWeather: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "City and state, e.g. Alpharetta, GA")
        var location: String

        @LLMToolGuide(description: "Temperature unit", .anyOf(["celsius", "fahrenheit"]))
        var unit: String?
    }

    public static var isConcurrencySafe: Bool { true }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        ToolOutput(content: "{\"temperature\": 22}")
    }
}
```

- `@LLMTool` — decorates the tool struct. Synthesizes `name` (snake_case of struct name, e.g. `GetCurrentWeather` → `get_current_weather`), `description` (from the doc comment), and `toolDefinition: ToolDefinition`.
- `@LLMToolArguments` — decorates the nested `Arguments` struct. Synthesizes `jsonSchema` from the struct's stored properties.
- `@LLMToolGuide(description:)` — annotates individual properties with descriptions and optional schema constraints. The constraint is the unlabeled second argument.
- `AgentLLMTool` — the protocol that bridges `LLMTool` and `AgentToolProtocol`. Provides default implementations for `inputSchema` (bridged from `toolDefinition`) and `execute(input:)` (calls `call(arguments:)`). You only implement `call(arguments:)`.
- `call(arguments:)` returns `ToolOutput(content:)` — a wrapper around the result string.

---

## LLMToolGuide constraint options

| Constraint | Swift | Example |
|------------|-------|---------|
| Enum of allowed values | `.anyOf(["a", "b"])` | `@LLMToolGuide(description: "Unit", .anyOf(["celsius", "fahrenheit"]))` |
| Integer range | `.range(1...100)` | `@LLMToolGuide(description: "Limit", .range(1...100))` |
| Double range | `.doubleRange(0.0...1.0)` | `@LLMToolGuide(description: "Confidence", .doubleRange(0.0...1.0))` |
| Array count (exact) | `.count(3)` | `@LLMToolGuide(description: "Tags", .count(3))` |
| Array min count | `.minimumCount(1)` | `@LLMToolGuide(description: "Items", .minimumCount(1))` |
| Array max count | `.maximumCount(10)` | `@LLMToolGuide(description: "Results", .maximumCount(10))` |

---

## isConcurrencySafe

Declare on every tool whether it is safe to run concurrently with other tools:

```swift
public static var isConcurrencySafe: Bool { true }   // or false
```

Default (from `AgentLLMTool`) is `false`. Override to `true` for pure functions, read-only operations, arithmetic, and text processing. Use `false` for file writes, database mutations, or any operation that modifies shared state.

---

## Registration

```swift
let tools = ToolRegistry()
tools.register(GetCurrentWeather())
tools.register(AnotherTool())
```

`ToolRegistry.register` accepts any `AgentLLMTool` conformance. The registry derives the tool's schema from `toolDefinition` via `AgentLLMTool.inputSchema`.

---

## Dispatch via AgentToolLoop

For all tool-using agents, pass the registry to `AgentToolLoop.run()`:

```swift
let result = try await AgentToolLoop.run(
    client: client,
    config: config,
    goal: goal,
    tools: tools,
    transcript: _transcript,
    maxIterations: maxToolIterations,
    hooks: hooks           // optional
    guardrails: pipeline   // optional
)
```

`AgentToolLoop` handles the full send/dispatch/loop cycle, including:
- Sending the initial request with all tool definitions
- Detecting tool calls in the response
- Dispatching safe tools concurrently, unsafe tools sequentially (via `isConcurrencySafe`)
- Appending `.toolCall` and `.toolResult` transcript entries in receive order
- Feeding results back to the LLM
- Enforcing `maxIterations`

---

## ToolRegistry

```swift
public final class ToolRegistry: @unchecked Sendable {
    public func register<T: AgentLLMTool>(_ tool: T)
    public func definitions() -> [FunctionToolParam]
    public func dispatch(name: String, callId: String, arguments: String) async throws -> ToolResult
    public func dispatchBatch(_ calls: [AgentToolCall]) async throws -> [ToolResult]
    public var toolNames: [String] { get }
    public var isEmpty: Bool { get }
    public var permissionGate: PermissionGate? { get set }
}
```

Set `permissionGate` before passing the registry to `AgentToolLoop` to enable tool-level access control.
