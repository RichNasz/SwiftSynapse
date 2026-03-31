# Shared Spec: Tool Concurrency

> Defines how SwiftSynapse agents schedule tool calls safely and efficiently, manage result ordering, and prevent context window overflow.

---

## Summary

Tool-using agents can receive multiple simultaneous tool calls from the LLM in a single response. Tools that are safe to run in parallel (read-only, pure) should run concurrently. Tools with side effects must run exclusively. Results are emitted in the order the tools were received, not the order they completed. Tool output is bounded by a token budget before being returned to the LLM.

---

## Concurrency Safety Declaration

Every tool type declares whether it is safe to run concurrently with other tools. This is expressed as a computed property on the tool struct or class:

```swift
// For tools defined via @LLMTool macro:
var isConcurrencySafe: Bool { true }   // or false
```

Guidelines:
- **`true`** (concurrent-safe): Pure functions, read-only operations, web fetches, database reads, arithmetic, unit conversion, text processing.
- **`false`** (exclusive): File writes, database mutations, API calls with side effects, any operation that modifies shared state.

When in doubt, use `false`. Correctness is more important than parallelism.

---

## ToolExecutor Actor

The `ToolExecutor` is an actor provided by `SwiftSynapseMacrosClient` that schedules tool calls and returns results in receive order:

```swift
public actor ToolExecutor {
    public func execute(
        calls: [(name: String, arguments: String, index: Int)],
        dispatch: @Sendable (String, String) async throws -> String
    ) async throws -> [(index: Int, result: String)]
}
```

Behavior:
1. All concurrent-safe tools with `isConcurrencySafe == true` are launched together via `withTaskGroup`.
2. All exclusive tools with `isConcurrencySafe == false` are queued and run one at a time, interleaved with concurrent batches.
3. Results accumulate internally. When all calls complete, results are sorted by `index` and returned in receive order.
4. If any tool throws, the executor cancels remaining concurrent tasks, collects results so far, and rethrows the error.

Agents do not implement `ToolExecutor` themselves — they call it.

---

## Tool Dispatch Loop Pattern

The tool dispatch loop runs inside `execute(goal:)` after the LLM responds with tool calls. It repeats until the LLM produces a non-tool response:

```swift
var messages: [Message] = [.user(goal)]

while true {
    let response = try await retryWithBackoff(maxAttempts: maxRetries) {
        try await _llmClient.send(request(messages: messages))
    }

    guard let toolCalls = response.firstFunctionCalls, !toolCalls.isEmpty else {
        // LLM produced a final text response — done
        let text = response.firstOutputText ?? ""
        guard !text.isEmpty else {
            let e = MyAgentError.noResponseContent
            _status = .error(e)
            throw e
        }
        _transcript.append(.assistantMessage(text))
        _status = .completed(text)
        return text
    }

    // Execute all tool calls
    let indexed = toolCalls.enumerated().map { (name: $0.element.name, arguments: $0.element.arguments, index: $0.offset) }
    let results = try await toolExecutor.execute(calls: indexed, dispatch: dispatchTool)

    // Append transcript entries in receive order
    for (i, call) in toolCalls.enumerated() {
        let result = results.first(where: { $0.index == i })?.result ?? ""
        _transcript.append(.toolCall(name: call.name, arguments: call.arguments))
        _transcript.append(.toolResult(name: call.name, result: result, duration: .zero))
    }

    // Feed results back to LLM
    messages.append(.toolResults(results.map { (id: toolCalls[$0.index].id, content: $0.result) }))
}
```

---

## Tool Dispatch Function

`dispatchTool` maps tool names to implementations:

```swift
private func dispatchTool(name: String, arguments: String) async throws -> String {
    switch name {
    case MyTool.toolDefinition.name:
        let args = try JSONDecoder().decode(MyTool.Arguments.self, from: Data(arguments.utf8))
        return try await myTool.call(args)
    default:
        throw MyAgentError.unknownTool(name)
    }
}
```

Rules:
- The `switch` is exhaustive over all registered tools.
- `default` always throws `unknownTool(name)`.
- Tool argument decoding errors (invalid JSON) throw immediately without retry.
- The result is always a `String` — tools that return structured data must encode it as JSON.

---

## Tool Result Budgeting

Before appending a tool result to the transcript or feeding it back to the LLM, apply the token budget:

```swift
private func budget(_ result: String, limit: Int) -> String {
    // Rough approximation: 1 token ≈ 4 characters
    let charLimit = limit * 4
    guard result.count > charLimit else { return result }
    return String(result.prefix(charLimit)) + "\n[TRUNCATED — tool result exceeded \(limit) token budget]"
}
```

Apply the budget in `dispatchTool`:

```swift
let raw = try await myTool.call(args)
return budget(raw, limit: toolResultBudgetTokens)
```

The `toolResultBudgetTokens` value comes from `AgentConfiguration` (default: 4096). A value of 0 disables budgeting.

---

## Transcript Ordering Guarantee

Tool entries are **always** appended in the order the LLM issued the tool calls, regardless of when each tool completed. The `ToolExecutor.execute()` return value is sorted by receive index before transcript appending. This guarantee is required for transcripts to be deterministic and replayable.

---

## Max Tool Iterations

Agents must guard against infinite tool loops. Add a `maxToolIterations` constant (default: 10) and throw if exceeded:

```swift
var iteration = 0
while true {
    iteration += 1
    guard iteration <= maxToolIterations else {
        let e = MyAgentError.toolLoopExceeded
        _status = .error(e)
        throw e
    }
    // ... dispatch and loop
}
```

`toolLoopExceeded` is a required case in the error enum of any tool-using agent.
