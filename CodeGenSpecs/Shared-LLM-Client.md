# Shared Spec: LLM Client

> Defines how all SwiftSynapse agents communicate with language models via SwiftOpenResponsesDSL.

---

## Summary

Cloud-based agents communicate with Open Responses API-compatible endpoints through `SwiftOpenResponsesDSL.LLMClient`. On-device agents use `FoundationModelsClient` (see `Shared-Foundation-Models.md`). Both conform to the `AgentLLMClient` protocol, which is the abstraction agents should program against.

For cloud-only agents or legacy agents, `LLMClient` may be used directly. New agents using `AgentConfiguration` receive an `AgentLLMClient` instance based on the configured `ExecutionMode`.

---

## Client

- Type: `SwiftOpenResponsesDSL.LLMClient`
- Initialization: `LLMClient(baseURL: endpointURL, apiKey: apiKey ?? "")`
- The `endpointURL` must be a full Open Responses API endpoint URL (e.g. `http://127.0.0.1:1234/v1/responses`).
- Agents construct the client in `init` and store it as a `let` property.

---

## Request

Built with the `ResponseRequest` DSL builder:

```swift
let request = ResponseRequest(model: modelName) {
    // optional config (temperature, maxTokens, tools, etc.)
} input: {
    // InputBuilder: User(_:), System(_:), InputMessage(role:content:)
    User(goal)
}
```

- `RequestTimeout(300)` and `ResourceTimeout(300)` must always be set in the config block (5-minute timeout for local LLM inference).
- `User(_:)` — adds a user-role input message.
- `System(_:)` — adds a system-role input message.
- `InputMessage(role:content:)` — adds an arbitrary-role input message.

---

## Response

- `client.send(request)` returns `ResponseObject`.
- Extract text: `response.firstOutputText` → `String?`
- Extract tool calls: `response.firstFunctionCalls` → `[FunctionCallItem]`

---

## Tools

Tool params are constructed from `@LLMTool`-decorated structs (from `SwiftLLMToolMacros`):

```swift
FunctionToolParam(tool.toolDefinition)
```

Pass these into the `ResponseRequest` config block via a `@ToolsBuilder` block or `tools` array.

Tool call dispatch:
1. Match `FunctionCallItem.name` against `MyTool.name`.
2. Decode arguments: `call.decodeArguments() as MyTool.Arguments`
3. Call: `try await myTool.call(arguments:)`
4. Return: `ToolOutput.content`

---

## Streaming

For agents that consume streaming responses (see `Shared-Transcript.md` for the streaming lifecycle), `LLMClient` provides a streaming variant:

```swift
let stream: AsyncThrowingStream<String, Error> = try await client.stream(request)
```

- `stream(request:)` returns an `AsyncThrowingStream<String, Error>` that yields text chunks as they arrive.
- The `ResponseRequest` must include `StreamingEnabled()` in its config block to signal the server.
- Error handling: if the stream fails mid-flight, the error is thrown from the `for try await` loop. Partial results are lost — agents must not retry mid-stream (see `StreamingChatAgent` spec).
- Token counts and response metadata are not available per-chunk. Agents that need token counts should extract them from a summary event at the end of the stream, or estimate from accumulated text length.

If `SwiftOpenResponsesDSL.LLMClient` does not yet expose `stream(request:)`, the agent spec should note this as a dependency and use `send(request:)` as a fallback (non-streaming) until the method is available.

---

## AgentLLMClient Protocol

For agents that support both on-device and cloud inference, the `AgentLLMClient` protocol provides a unified interface. See `Shared-Foundation-Models.md` for the full protocol definition, `AgentRequest`/`AgentResponse` types, and the `HybridLLMClient` fallback pattern.

`LLMClient` conforms to `AgentLLMClient` via an extension that bridges `AgentRequest` → `ResponseRequest` and `ResponseObject` → `AgentResponse`.

---

## Endpoint requirement (cloud path)

When using the cloud path (`.cloud` or `.hybrid` execution mode), agents must communicate with Open Responses API-compatible endpoints only (path `/v1/responses`). Chat Completions endpoints (`/v1/chat/completions`) are not supported.
