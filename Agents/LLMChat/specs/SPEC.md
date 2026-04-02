# LLMChat Agent Specification

## Purpose

Forward a user prompt to an Open Responses API-compatible endpoint and return the model's reply.

---

## Configuration

| Parameter       | Type                 | Default | Description                            |
|-----------------|----------------------|---------|----------------------------------------|
| `configuration` | `AgentConfiguration` | —       | Server URL, model, API key, timeout    |

Uses the shared `AgentConfiguration` type (see `Shared-Configuration.md`). URL and model validation occurs at init time via `AgentConfigurationError`.

---

## Input

| Parameter | Type     | Description               |
|-----------|----------|---------------------------|
| `goal`    | `String` | The prompt to send to the LLM |

---

## Tasks

1. Validate `goal` is non-empty; set status `.error(LLMChatError.emptyGoal)` and throw if empty.
2. Set status to `.running`; append a `.userMessage` transcript entry with `goal`.
3. Build a `ResponseRequest` with `RequestTimeout(300)` and `ResourceTimeout(300)` in the config block, and `User(goal)` as input.
4. Call `try await _llmClient.send(request)`; extract text via `response.firstOutputText`.
5. Guard non-empty result → `.error(LLMChatError.noResponseContent)` + throw.
6. Append a `.assistantMessage` transcript entry with the response text; set status `.completed`; return the response text.

---

## Errors

| Case                  | Thrown when                                        |
|-----------------------|----------------------------------------------------|
| `emptyGoal`           | `goal` is an empty string                          |
| `noResponseContent`   | The model reply is empty or missing                |

URL and configuration validation errors are handled by `AgentConfigurationError` (shared type from `SwiftSynapseHarness`).

---

## Tools

None for this agent. When tools are needed in other agents, define them with `@LLMTool` + `@LLMToolArguments` from `SwiftLLMToolMacros`; pass `FunctionToolParam(tool.toolDefinition)` to the request builder.

---

## Output

The LLM's reply as a `String`.

---

## Constraints

- Import `SwiftSynapseHarness`; no raw URLSession or OpenAI SDK.
- All tool definitions (if any) must use `@LLMTool` / `@LLMToolArguments` (available via `SwiftSynapseHarness`).
- Endpoint must be an Open Responses API-compatible `/v1/responses` URL (not `/v1/chat/completions`).
- Request and resource timeouts must both be set to 300 seconds (5 minutes) to accommodate slow local LLM inference.
- No data persistence.
- Configuration is init-time via `AgentConfiguration`, not per-request.
- Must handle empty goal and empty/missing response content.

---

## Success Criteria

- Status is `.completed` after a successful run.
- Transcript contains exactly 2 entries (user, assistant).
- Throws `LLMChatError.emptyGoal` when goal is `""`.
- Throws `AgentConfigurationError` for invalid URL or configuration.
- Propagates network/server errors from `LLMClient`.
