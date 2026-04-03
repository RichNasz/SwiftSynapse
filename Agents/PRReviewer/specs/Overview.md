# Code Generation Overview: PRReviewer

> Instructs the code generator on what files to produce and how to assemble them from SPEC.md and shared CodeGenSpecs.

---

## Files to Generate

| File | Target | Purpose |
|------|--------|---------|
| `Sources/PRReviewer.swift` | `PRReviewerAgent` library | Error enum + tool structs + agent actor |
| `CLI/PRReviewerCLI.swift` | `pr-reviewer` executable | ArgumentParser CLI with terminal ApprovalDelegate |
| `Tests/PRReviewerTests.swift` | `PRReviewerTests` test target | Swift Testing suite |

All tool structs live in `Sources/PRReviewer.swift` above the agent actor, separated by `// MARK: - Tool Definitions`.

---

## Shared Types Used

- `AgentConfiguration` — centralized config with validation
- `@LLMTool` / `@LLMToolArguments` / `@LLMToolGuide` — macro stack for compile-time tool schema generation
- `AgentLLMTool` — protocol bridging `LLMTool` and `AgentToolProtocol`; only `call(arguments:) -> ToolOutput` required
- `ToolRegistry` — registers `AgentLLMTool` conformances and dispatches calls
- `AgentToolLoop.run()` — tool dispatch loop with safety integration
- `StreamingToolExecutor` — concurrent tool dispatch during streaming
- `GuardrailPipeline` / `GuardrailPolicy` / `ContentFilter` — content safety
- `PermissionGate` / `ToolListPolicy` / `ApprovalDelegate` — tool access control
- `ResultTruncator` / `TruncationPolicy` — oversized result handling
- `CachePolicy` — tool result caching
- `AgentHookPipeline` / `ClosureHook` — lifecycle event hooks
- `@SpecDrivenAgent` macro — generates observable state
- `AgentConfigurationError` — config validation errors

---

## Shared Specs to Apply

1. `Shared-Configuration.md` — `AgentConfiguration` init pattern
2. `Shared-Guardrails.md` — `GuardrailPipeline` setup and evaluation
3. `Shared-Permission-System.md` — `PermissionGate` with `ToolListPolicy` and `ApprovalDelegate`
4. `Shared-Agent-Tool-Loop.md` — `AgentToolLoop.runStreaming()` with safety integration
5. `Shared-Streaming-Tool-Executor.md` — concurrent tool dispatch during streaming
6. `Shared-Result-Truncation.md` — `ResultTruncator` for large diffs
7. `Shared-Caching.md` — tool result caching for repeated analyses
8. `Shared-Hook-System.md` — `guardrailTriggered`, `preToolUse`, `postToolUse` hooks
9. `Shared-Tool-Registry.md` — `AgentLLMTool` conformances
10. `Shared-Error-Strategy.md` — error enum, status-before-throw

---

## Actor State Properties

```swift
@SpecDrivenAgent
public actor PRReviewer {
    private let config: AgentConfiguration
    private let guardrailPipeline: GuardrailPipeline
    private let permissionGate: PermissionGate
    private let hookPipeline: AgentHookPipeline
    private let toolRegistry: ToolRegistry
}
```

---

## Init Rules

1. Primary init takes `AgentConfiguration`.
2. Configures `GuardrailPipeline` with `ContentFilter.default` + custom patterns.
3. Configures `PermissionGate` with `ToolListPolicy` rules.
4. Registers all 5 tools in `ToolRegistry`.
5. Sets up `AgentHookPipeline` with logging hooks.

---

## execute() Rules

1. Guard non-empty goal.
2. Set `ApprovalDelegate` if provided.
3. Build system prompt via `SystemPromptBuilder`.
4. Run `AgentToolLoop.runStreaming()` with all safety infrastructure.
5. Guard non-empty result; set status; return.

---

## CLI Rules

Uses `AgentConfiguration.fromEnvironment(overrides:)`. Includes `--diff-path` option for local diffs. Implements terminal-based `ApprovalDelegate` via stdin prompt.

---

## Test Rules

1. `prReviewerThrowsOnEmptyGoal` — empty goal error
2. `prReviewerGuardrailBlocksSecrets` — output containing API key triggers block
3. `prReviewerPermissionDeniesDestructive` — destructive patch denied
4. `prReviewerApprovalDelegateCalledForFetchDiff` — approval requested
5. `prReviewerTruncatesLargeDiffs` — large result truncated
6. `prReviewerCachesRepeatedAnalysis` — second call returns cached result
7. `prReviewerConcurrentToolDispatch` — concurrent-safe tools run in parallel
