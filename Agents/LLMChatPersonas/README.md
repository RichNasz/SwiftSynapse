<!-- Generated from CodeGenSpecs/Agent-README-Generation.md + Agents/LLMChatPersonas/specs/SPEC.md — Do not edit manually. -->

# LLMChatPersonas

Two-step LLM pipeline: get a plain response, then optionally rewrite it in any persona's voice using conversation threading.

## Overview

LLMChatPersonas extends LLMChat with an optional second LLM call that rewrites the initial response in the voice and style of a named persona. When a persona is provided, the second request uses `PreviousResponseId` to thread the conversation — rather than embedding the full response text, it sends a short follow-up instruction and lets the API supply the prior context. The CLI prints both the original and persona-rewritten responses with labeled sections when `--persona` is given.

**Platforms:** iOS 26+, macOS 26+, visionOS 2.4+

## Quick Start

**CLI — plain response:**

```bash
swift run llm-chat-personas "Explain black holes." \
    --server-url http://127.0.0.1:1234/v1/responses \
    --model llama3
```

**CLI — with persona (prints both responses):**

```bash
swift run llm-chat-personas "Explain black holes." \
    --server-url http://127.0.0.1:1234/v1/responses \
    --model llama3 \
    --persona pirate
```

Output:

```
--- Original Response ---
A black hole is a region of spacetime where gravity is so strong that...

--- pirate Response ---
Arrr, ye landlubber! A black hole be a fearsome void in the cosmos where...
```

**Programmatic — no persona:**

```swift
import LLMChatPersonasAgent

let agent = try LLMChatPersonas(
    serverURL: "http://127.0.0.1:1234/v1/responses",
    modelName: "llama3"
)
let reply = try await agent.execute(goal: "What is a neutron star?")
print(reply)
```

**Programmatic — with persona:**

```swift
let agent = try LLMChatPersonas(
    serverURL: "http://127.0.0.1:1234/v1/responses",
    modelName: "llama3"
)
let personaReply = try await agent.execute(goal: "What is a neutron star?", persona: "Yoda")

// Access the original (pre-rewrite) response
let original = await agent.lastInitialResponse
```

## Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `serverURL` | `String` | — | Full URL of an Open Responses API endpoint (e.g. `http://127.0.0.1:1234/v1/responses`) |
| `modelName` | `String` | — | Model identifier (e.g. `llama3`, `gpt-4o`) |
| `apiKey` | `String?` | `nil` | Optional API key for authenticated endpoints |

URL validation occurs at init time. Throws `LLMChatPersonasError.invalidServerURL` if the string is empty, unparseable, or uses a non-http/https scheme.

## Input

| Parameter | Type | Description |
|-----------|------|-------------|
| `goal` | `String` | The prompt to send to the LLM |
| `persona` | `String?` | Optional persona name for the rewrite step (e.g. `"pirate"`, `"James Kirk"`, `"Yoda"`) |

## Output

The final LLM reply as a `String` — persona-rewritten if a persona was provided, plain otherwise.

The original (pre-persona) response is also available via `agent.lastInitialResponse: String?` after `execute()` returns.

## How It Works

**Without persona (2-step):**

1. **Validate goal** — Guard non-empty; throw `LLMChatPersonasError.emptyGoal` and set status `.error(...)` if empty.
2. **Start running** — Set status to `.running`; append `.userMessage(goal)` to transcript.
3. **First request** — `ResponseRequest` with `RequestTimeout(300)` + `ResourceTimeout(300)`, `User(goal)` as input.
4. **Guard response** — Empty reply -> set status `.error(...)` + throw `LLMChatPersonasError.noResponseContent`.
5. **Store** — Save `initialResponse` to `lastInitialResponse`; append `.assistantMessage(initialResponse)`.
6. **Complete** — Set status `.completed(initialResponse)`; return `initialResponse`.

**With persona (4-step):**

Steps 1-5 above, then:

6. **Capture ID** — Record `firstResponseId = firstResponse.id` for conversation threading.
7. **Build persona prompt** — Short follow-up instruction (no embedded response text):
   > *"Rewrite your previous response in the style and voice of {persona}. Preserve all factual content but express it exactly as {persona} would speak."*
8. **Append** — `.userMessage(personaPrompt)` to transcript.
9. **Second request** — `ResponseRequest` with `PreviousResponseId(firstResponseId)` in the config block; API supplies conversation context from history.
10. **Guard persona response** — Empty reply -> set status `.error(...)` + throw `LLMChatPersonasError.noPersonaResponseContent`.
11. **Complete** — Append `.assistantMessage(personaResponse)`; set status `.completed(personaResponse)`; return `personaResponse`.

## Transcript Shape

| Scenario | Entries |
|----------|---------|
| No persona | `[.userMessage(goal), .assistantMessage(response)]` — 2 entries |
| With persona | `[.userMessage(goal), .assistantMessage(initial), .userMessage(personaPrompt), .assistantMessage(personaFinal)]` — 4 entries |

## Errors

| Case | Thrown when |
|------|-------------|
| `LLMChatPersonasError.emptyGoal` | `goal` is an empty string |
| `LLMChatPersonasError.invalidServerURL` | `serverURL` is empty, unparseable, or non-http/https |
| `LLMChatPersonasError.noResponseContent` | The first model reply is empty or missing |
| `LLMChatPersonasError.noPersonaResponseContent` | The persona-rewrite reply is empty or missing |

Network and server errors from `LLMClient` are propagated directly.

## Testing

```bash
swift test --filter LLMChatPersonasTests
```

Tests validate:
- Status is `.idle` before `execute()` is called
- Throws `LLMChatPersonasError.emptyGoal` when `goal` is `""`
- Throws `LLMChatPersonasError.invalidServerURL` for malformed or non-http/https URLs
- (Persona/network-dependent tests require a live endpoint and are not included in the unit suite)

## Constraints

- Imports `SwiftSynapseMacrosClient`; no raw `URLSession` or OpenAI SDK
- Endpoint must be an Open Responses API-compatible `/v1/responses` URL (not `/v1/chat/completions`)
- Both `RequestTimeout` and `ResourceTimeout` are set to 300 seconds for both LLM calls
- The persona prompt does **not** embed the full initial response text — it relies on `PreviousResponseId` conversation threading
- No data persistence; server URL and model are init-time, not per-request

## File Structure

```
Agents/LLMChatPersonas/
├── specs/
│   ├── SPEC.md
│   └── Overview.md
├── README.md
├── Sources/
│   └── LLMChatPersonas.swift
├── CLI/
│   └── LLMChatPersonasCLI.swift
└── Tests/
    └── LLMChatPersonasTests.swift
```

## Related

- [specs/SPEC.md](specs/SPEC.md) — agent specification
- [specs/Overview.md](specs/Overview.md) — generation rules
- [LLMChat](../LLMChat/README.md) — the single-step foundation this agent extends
- [Root README.md](../../README.md) — project overview
