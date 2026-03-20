# LLMChat Agent Specification

## Purpose

Forward a user prompt to an Open Responses API-compatible endpoint and return the model's reply.

---

## Configuration (constructor parameters)

| Parameter    | Type      | Default | Description                            |
|--------------|-----------|---------|----------------------------------------|
| `serverURL`  | `String`  | —       | Full URL of an Open Responses API endpoint (e.g. `http://127.0.0.1:1234/v1/responses`) |
| `modelName`  | `String`  | —       | Model identifier (e.g. `llama3`, `gpt-4o`) |
| `apiKey`     | `String?` | `nil`   | Optional API key for authentication    |

URL validation occurs at init time; throws `LLMChatError.invalidServerURL` if the string is not a valid URL.

---

## Input

| Parameter | Type     | Description               |
|-----------|----------|---------------------------|
| `goal`    | `String` | The prompt to send to the LLM |

---

## Tasks

1. Validate `goal` is non-empty; throw `LLMChatError.emptyGoal` and set status `.failed` if empty.
2. Set status to `.running`; append a `.user` transcript entry with `goal`.
3. Build a `ResponseRequest` with `RequestTimeout(300)` and `ResourceTimeout(300)` in the config block, and `User(goal)` as input.
4. Call `try await client.send(request)`; extract text via `response.firstOutputText`.
5. Guard non-empty result → `.failed` + throw `LLMChatError.noResponseContent`.
6. Append a `.assistant` transcript entry with the response text; set status `.completed`; return the response text.

---

## Errors

| Case                  | Thrown when                                        |
|-----------------------|----------------------------------------------------|
| `emptyGoal`           | `goal` is an empty string                          |
| `invalidServerURL`    | `serverURL` cannot be parsed as a `URL`            |
| `noResponseContent`   | The model reply is empty or missing                |

---

## Tools

None for this agent. When tools are needed in other agents, define them with `@LLMTool` + `@LLMToolArguments` from `SwiftLLMToolMacros`; pass `FunctionToolParam(tool.toolDefinition)` to the request builder.

---

## Output

The LLM's reply as a `String`.

---

## Constraints

- Import `SwiftOpenResponsesDSL` and `SwiftSynapseMacrosClient`; no raw URLSession or OpenAI SDK.
- All tool definitions (if any) must use `@LLMTool` / `@LLMToolArguments` from `SwiftLLMToolMacros`.
- Endpoint must be an Open Responses API-compatible `/v1/responses` URL (not `/v1/chat/completions`).
- Request and resource timeouts must both be set to 300 seconds (5 minutes) to accommodate slow local LLM inference.
- No data persistence.
- Server URL and model are init-time, not per-request.
- Must handle empty goal and empty/missing response content.

---

## Success Criteria

- Status is `.completed` after a successful run.
- Transcript contains exactly 2 entries (user, assistant).
- Throws `LLMChatError.emptyGoal` when goal is `""`.
- Throws `LLMChatError.invalidServerURL` when the URL string is malformed.
- Propagates network/server errors from `LLMClient`.
