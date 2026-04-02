# Shared Spec: Tool Registry

> Defines how LLM tools are defined, registered, and dispatched across all SwiftSynapse agents using SwiftLLMToolMacros.

---

## Summary

Tools are defined as Swift structs decorated with `@LLMTool` from `SwiftLLMToolMacros`. The macro synthesizes `name`, `description`, and `toolDefinition: ToolDefinition` on the struct, which maps directly to `FunctionToolParam` in `SwiftOpenResponsesDSL`. No JSON schema is written by hand.

---

## Tool definition

```swift
@LLMTool(description: "Fetch the current weather for a location.")
struct WeatherTool {
    @LLMToolArguments
    struct Arguments {
        @LLMToolGuide(description: "City name", constraint: "Non-empty string")
        var location: String
    }

    func call(arguments: Arguments) async throws -> String {
        // implementation
    }
}
```

- `@LLMTool` — decorates the tool struct; provides `name` (derived from type name) and `toolDefinition`.
- `@LLMToolArguments` — decorates the nested `Arguments` struct; provides `jsonSchema`.
- `@LLMToolGuide(description:constraint:)` — annotates individual properties with descriptions and constraints for schema generation.

---

## Registration in a request

```swift
let request = ResponseRequest(model: modelName) {
    FunctionToolParam(WeatherTool.toolDefinition)
} input: {
    User(goal)
}
```

Pass `FunctionToolParam(tool.toolDefinition)` for each tool in the config (tools) block of `ResponseRequest`.

---

## Dispatch

```swift
if let calls = response.firstFunctionCalls {
    for call in calls {
        switch call.name {
        case WeatherTool.name:
            let args = try call.decodeArguments() as WeatherTool.Arguments
            let result = try await weatherTool.call(arguments: args)
            // return ToolOutput.content(result)
        default:
            break
        }
    }
}
```

1. Retrieve tool calls via `response.firstFunctionCalls`.
2. Match `FunctionCallItem.name` against each tool's `name` static property.
3. Decode arguments with `call.decodeArguments() as ToolType.Arguments`.
4. Call `tool.call(arguments:)` and surface the result as `ToolOutput.content`.

---

## AgentToolProtocol (Typed Tool Registration)

For agents using `ToolRegistry` and `AgentToolLoop` (recommended for new tool-using agents), tools conform to `AgentToolProtocol`:

```swift
public protocol AgentToolProtocol: Sendable {
    associatedtype Input: Codable & Sendable
    associatedtype Output: Codable & Sendable
    static var name: String { get }
    static var description: String { get }
    static var inputSchema: FunctionToolParam { get }
    var isConcurrencySafe: Bool { get }
    func execute(input: Input) async throws -> Output
}
```

Tools registered via `ToolRegistry` are dispatched automatically by `AgentToolLoop` — see `Shared-Agent-Tool-Loop.md` for the high-level dispatch pattern. The manual switch-based dispatch above remains valid for simple agents.

---

## ToolRegistry

```swift
public final class ToolRegistry: @unchecked Sendable {
    public func register<T: AgentToolProtocol>(_ tool: T)
    public func definitions() -> [FunctionToolParam]
    public func dispatch(name: String, arguments: String) async throws -> ToolResult
    public func dispatchBatch(_ calls: [AgentToolCall]) async throws -> [ToolResult]
    public var toolNames: [String] { get }
    public var isEmpty: Bool { get }
}
```
