# Shared Spec: LLM Client

> Defines how all SwiftSynapse agents communicate with language models via SwiftOpenResponsesDSL.

---

## Summary

All agents communicate with Open Responses API-compatible endpoints through `SwiftOpenResponsesDSL.LLMClient`. This is the single concrete implementation — no raw URLSession, no OpenAI SDK, no Chat Completions endpoints.

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

## Endpoint requirement

All agents must communicate with Open Responses API-compatible endpoints only (path `/v1/responses`). Chat Completions endpoints (`/v1/chat/completions`) are not supported.
