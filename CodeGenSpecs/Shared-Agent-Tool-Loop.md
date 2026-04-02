# Shared Spec: Agent Tool Loop

> Core trait — high-level tool dispatch loop with recovery, hooks, telemetry, and permissions.

---

## Summary

`AgentToolLoop` is the preferred high-level pattern for tool-using agents. It orchestrates the full cycle: send prompt to LLM → receive response → dispatch tool calls → feed results back → repeat until the LLM produces a final text response. It integrates hooks, permissions, guardrails, recovery, and telemetry automatically.

This supersedes the manual `ToolExecutor` dispatch pattern (see `Shared-Tool-Concurrency.md`) for most use cases.

---

## Core API

```swift
public enum AgentToolLoop {
    /// Non-streaming tool loop
    public static func run(
        client: any AgentLLMClient,
        request: AgentRequest,
        toolRegistry: ToolRegistry,
        maxIterations: Int = 10,
        hookPipeline: AgentHookPipeline? = nil,
        permissionGate: PermissionGate? = nil,
        guardrailPipeline: GuardrailPipeline? = nil,
        recoveryChain: RecoveryChain? = nil,
        telemetrySink: (any TelemetrySink)? = nil,
        onTranscriptEntry: @Sendable (TranscriptEntry) -> Void = { _ in }
    ) async throws -> AgentResponse

    /// Streaming tool loop
    public static func runStreaming(
        client: any AgentLLMClient,
        request: AgentRequest,
        toolRegistry: ToolRegistry,
        maxIterations: Int = 10,
        // ... same optional parameters ...
        onStreamEvent: @Sendable (AgentStreamEvent) -> Void
    ) async throws -> AgentResponse
}
```

---

## Loop Behavior

Each iteration:
1. Fire `llmRequestSent` hook (can modify prompt)
2. Send request to LLM client
3. Fire `llmResponseReceived` hook
4. If response contains tool calls:
   a. For each tool call: fire `preToolUse` hook → check permissions → evaluate guardrails → dispatch via `ToolRegistry` → fire `postToolUse` hook
   b. Collect all tool results
   c. Build next request with tool results
   d. Increment iteration counter; throw `ToolDispatchError.loopExceeded` if `maxIterations` reached
5. If response is final text: return `AgentResponse`
6. On recoverable error: invoke `RecoveryChain`, retry if recovered

---

## ToolDispatchError

```swift
public enum ToolDispatchError: Error, Sendable {
    case unknownTool(String)
    case loopExceeded(maxIterations: Int)
    case decodingFailed(toolName: String, error: Error)
    case encodingFailed(toolName: String, error: Error)
    case blockedByHook(toolName: String, reason: String)
    case permissionDenied(toolName: String, reason: String)
}
```

---

## Integration Points

- **ToolRegistry**: dispatches tool calls with concurrency-aware scheduling
- **Hooks**: fires pre/post tool use and LLM request/response events
- **Permissions**: checks `PermissionGate` before each tool dispatch
- **Guardrails**: evaluates tool arguments through `GuardrailPipeline`
- **Recovery**: invokes `RecoveryChain` on recoverable errors
- **Telemetry**: emits events for LLM calls, tool calls, retries
- **Transcript**: calls `onTranscriptEntry` for each entry (tool call, tool result, etc.)

---

## When to Use

- **Use `AgentToolLoop`** for agents that need full tool dispatch with lifecycle integration.
- **Use manual `ToolExecutor`** only when you need custom dispatch logic that the loop doesn't support.
- Simple agents without tools (LLMChat, StreamingChat) don't need either.
