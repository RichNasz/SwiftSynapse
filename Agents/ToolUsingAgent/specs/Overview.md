# Code Generation Overview: ToolUsingAgent

> Instructs the code generator on what files to produce and how to assemble them from SPEC.md and shared CodeGenSpecs.

---

## Files to Generate

| File | Target | Purpose |
|------|--------|---------|
| `Sources/ToolUsingAgent.swift` | `ToolUsingAgentAgent` library | Error enum + tool structs + agent actor |
| `CLI/ToolUsingAgentCLI.swift` | `tool-using-agent` executable | ArgumentParser CLI |
| `Tests/ToolUsingAgentTests.swift` | `ToolUsingAgentTests` test target | Swift Testing suite |

All tool structs live in `Sources/ToolUsingAgent.swift` above the agent actor, separated by `// MARK: - Tool Definitions`.

---

## Shared Types Used

- `AgentConfiguration` — centralized config with validation
- `@LLMTool` / `@LLMToolArguments` / `@LLMToolGuide` — macro stack for compile-time tool schema generation
- `AgentLLMTool` — protocol bridging `LLMTool` and `AgentToolProtocol`; only `call(arguments:) -> ToolOutput` is required
- `ToolRegistry` — registers `AgentLLMTool` conformances and dispatches calls
- `AgentToolLoop.run()` — handles the full tool dispatch loop with hooks, permissions, and telemetry
- `@SpecDrivenAgent` — generates `_status`, `_transcript`, `status`, `transcript`
- `AgentConfigurationError` — config validation errors

---

## Shared Specs to Apply

1. `Shared-Configuration.md` — `AgentConfiguration` init pattern
2. `Shared-Tool-Registry.md` — `@LLMTool` + `AgentLLMTool` + `ToolRegistry` pattern
3. `Shared-Agent-Tool-Loop.md` — `AgentToolLoop.run()` invocation
4. `Shared-Tool-Concurrency.md` — `isConcurrencySafe` classification
5. `Shared-Error-Strategy.md` — error enum placement, status-before-throw invariant

---

## Tool Struct Rules

Each tool is a public struct with:
1. A doc comment — becomes the synthesized `description`.
2. `@LLMTool` macro.
3. `AgentLLMTool` conformance.
4. `@LLMToolArguments` on the nested `Arguments` struct.
5. `@LLMToolGuide(description:)` on each property (with optional constraint as unlabeled second arg).
6. `public static var isConcurrencySafe: Bool { true/false }`.
7. `public func call(arguments: Arguments) async throws -> ToolOutput`.

No `name`, `description`, or `inputSchema` are written by hand — the macros synthesize all three.

---

## Actor State Properties

```swift
@SpecDrivenAgent
public actor ToolUsingAgent {
    private let config: AgentConfiguration
    private static let maxToolIterations = 10
}
```

---

## Init Rules

Single init taking `AgentConfiguration` (already validated by the time it reaches `init`). No legacy convenience init.

---

## execute() Rules

1. Build `ToolRegistry`, register `Calculate()`, `ConvertUnit()`, `FormatNumber()`.
2. Set `permissionGate` on registry if one is configured.
3. Call `AgentToolLoop.run(client:config:goal:tools:transcript:maxIterations:hooks:)`.
4. Guard non-empty result → `.noResponseContent`.
5. Return result string.

`AgentToolLoop` handles the entire dispatch loop, transcript appending, and concurrency scheduling internally.

---

## CLI Rules

Uses `AgentConfiguration.fromEnvironment(overrides:)` — `--server-url` and `--model` are optional, falling back to `SWIFTSYNAPSE_*` environment variables.

---

## Test Rules

1. `toolUsingAgentInitThrowsOnInvalidURL` — invalid URL → `AgentConfigurationError`
2. `toolUsingAgentInitialStateIsIdle` — `.idle` status, 0 transcript entries
3. `calculateToolReturnsResult` — `Calculate().call(arguments: .init(expression: "2+2"))` → `"4.0"`
4. `calculateToolDivision` — `"144/12"` → `"12.0"`
5. `calculateToolInvalidExpressionThrows` — empty sanitized expression → `.toolCallFailed`
6. `convertUnitMilesToKilometers` — `100 miles` → `"160934.4000"` km
7. `convertUnitCelsiusToFahrenheit` — `0 celsius` → `"32.0000"`
8. `convertUnitInvalidUnitThrows` — unknown unit → `.toolCallFailed`
9. `formatNumberTool` — `3.14159, decimalPlaces: 2` → `"3.14"`
10. `formatNumberToolClamps` — `decimalPlaces: 99` clamped to `10`
