# Shared Spec: Streaming Tool Executor

> Core trait — concurrent tool execution during streaming responses.

---

## Summary

`StreamingToolExecutor` enables tool dispatch while the LLM response is still streaming. As tool calls arrive in the stream, they are enqueued for execution immediately rather than waiting for the full response. This reduces total latency for tool-heavy responses.

---

## Core Type

```swift
public actor StreamingToolExecutor {
    public init(toolRegistry: ToolRegistry)
    public func enqueue(toolCall: AgentToolCall) async
    public func awaitAll() async throws -> [ToolResult]
    public var hasTools: Bool { get }
}
```

---

## Behavior

1. As `AgentStreamEvent.toolCall` events arrive during streaming, each tool call is enqueued.
2. Concurrent-safe tools (`isConcurrencySafe: true`) execute immediately in parallel.
3. Non-concurrent-safe tools are queued and executed sequentially after all concurrent tools complete.
4. `awaitAll()` returns results in the original LLM issuance order (not completion order), matching the receive-order guarantee from `Shared-Tool-Concurrency.md`.

---

## Integration Points

- **AgentToolLoop.runStreaming()**: uses `StreamingToolExecutor` internally
- **Tool Concurrency**: respects `isConcurrencySafe` declarations from tools
- **Hooks**: fires `preToolUse` / `postToolUse` for each enqueued tool
