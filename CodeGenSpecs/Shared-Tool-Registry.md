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
