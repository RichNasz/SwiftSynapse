# ResearchAssistant Agent Specification

> Reference implementation for Persistence trait (session + memory) and MCP trait — long-running research with cross-session recall, external data sources, and context window management.

## Purpose

Conduct iterative research across multiple sessions. Search the web, read documents, remember findings across sessions via persistent memory, connect to external data sources via MCP, manage growing context with budget tracking and compression, and produce evolving research reports.

---

## Configuration

| Parameter       | Type                 | Default | Description |
|-----------------|----------------------|---------|-------------|
| `configuration` | `AgentConfiguration` | —       | Server URL, model, API key, timeout, retries |
| `sessionStore`  | `SessionStore?`      | `FileSessionStore(directory: .sessionsDirectory)` | Session persistence backend |
| `memoryStore`   | `MemoryStore?`       | `FileMemoryStore(directory: .memoryDirectory)` | Cross-session memory backend |
| `mcpConfigs`    | `[MCPServerConfig]`  | `[]`    | Optional MCP server configurations |

---

## Input

| Parameter   | Type      | Description |
|-------------|-----------|-------------|
| `goal`      | `String`  | Research question or topic (e.g., "Research Swift concurrency best practices for iOS 26") |
| `sessionId` | `String?` | Optional — resume a previous research session |

---

## Tools (6 tools)

### searchWeb
- **Input**: `query: String`, `maxResults: Int`
- **Output**: JSON array of search results (title, url, snippet)
- **Side effects**: Network request (via MCP server or direct)
- **`isConcurrencySafe`**: `true`

### readDocument
- **Input**: `url: String`
- **Output**: Extracted text content (may be large — managed by `ContextBudget`)
- **Side effects**: Network request
- **`isConcurrencySafe`**: `true`

### saveMemory
- **Input**: `content: String`, `category: String`, `tags: [String]`
- **Output**: Confirmation with memory entry ID
- **Side effects**: Writes to `MemoryStore`
- **`isConcurrencySafe`**: `false`

### recallMemory
- **Input**: `query: String`, `category: String?`
- **Output**: JSON array of matching `MemoryEntry` items
- **Side effects**: Reads from `MemoryStore`
- **`isConcurrencySafe`**: `true`

### saveCheckpoint
- **Input**: None (captures current state)
- **Output**: Confirmation with session ID
- **Side effects**: Writes to `SessionStore`
- **`isConcurrencySafe`**: `false`

### generateReport
- **Input**: `topic: String`, `findings: String`
- **Output**: Formatted Markdown research report
- **Side effects**: None
- **`isConcurrencySafe`**: `true`

---

## Session Persistence

### Saving

After each major step (web search, document read, memory save), checkpoint the session:

```swift
let session = AgentSession(
    sessionId: currentSessionId,
    agentType: "ResearchAssistant",
    goal: goal,
    transcriptEntries: _transcript.entries.map(CodableTranscriptEntry.init),
    completedStepIndex: currentStep,
    customState: try JSONEncoder().encode(ResearchState(
        findings: accumulatedFindings,
        sourcesVisited: visitedURLs
    )),
    createdAt: sessionCreatedAt,
    savedAt: Date()
)
try await sessionStore.save(session)
```

Fire `sessionSaved` hook after each save.

### Resuming

When `sessionId` is provided:
1. Load session via `sessionStore.load(sessionId)`.
2. Validate `agentType == "ResearchAssistant"` — throw `sessionTypeMismatch` if wrong.
3. Restore transcript via `_transcript.restore(entries:)`.
4. Decode custom state to recover `ResearchState`.
5. Fire `sessionRestored` hook.
6. Resume `execute(goal:)` from `completedStepIndex + 1`.

---

## Memory System

### Categories Used

- `.project` — research findings and conclusions
- `.reference` — URLs and source citations
- `.custom("hypothesis")` — working hypotheses that evolve

### Cross-Session Recall

At the start of each research session (including resumed sessions), query `memoryStore` for relevant past findings:

```swift
let priorFindings = try await memoryStore.search(query: goal)
```

Inject relevant memories into the system prompt via `SystemPromptBuilder` so the LLM has context from prior research.

Fire `memoryUpdated` hook on each `saveMemory` call.

---

## MCP Integration

### Server Configuration

MCP servers provide external tools (web search, database access, document parsing). At init:

```swift
let mcpManager = MCPManager()
for config in mcpConfigs {
    try await mcpManager.connect(config)
}
await mcpManager.bridgeTools(into: toolRegistry)
```

MCP-bridged tools appear alongside native tools in the `ToolRegistry`. The agent does not distinguish between native and MCP tools during dispatch.

### Example MCP Server

```swift
MCPServerConfig(
    name: "web-search",
    transportType: .stdio(command: "npx", arguments: ["-y", "@anthropic/mcp-web-search"])
)
```

---

## Context Management

### ContextBudget

Track token usage across the research session:

```swift
var budget = ContextBudget(maxTokens: 100_000)
// After each LLM call:
budget.record(tokens: response.inputTokens + response.outputTokens)
```

### TranscriptCompressor

When `budget.utilizationPercentage > 0.8`, compress the transcript:

```swift
let compressor = SlidingWindowCompressor(windowSize: 30)
let compressed = compressor.compress(_transcript.entries)
_transcript.restore(entries: compressed)
budget.reset()
```

This preserves the most recent 30 entries, discarding older conversation history while keeping memory-persisted findings accessible via `recallMemory`.

---

## Tasks (execute steps)

1. Validate `goal` is non-empty. Set `_status = .error(ResearchAssistantError.emptyGoal)` and throw if empty.
2. If `sessionId` provided: load and restore session (validate type, restore transcript, decode state, fire `sessionRestored` hook).
3. Set `_status = .running`. Append `.userMessage(goal)`.
4. Connect MCP servers (if configured). Bridge MCP tools into `ToolRegistry`.
5. Query `memoryStore` for relevant prior findings. Inject into system prompt.
6. Initialize `ContextBudget`.
7. Register all 6 native tools in `ToolRegistry`.
8. Run `AgentToolLoop.run()` with:
   - `toolRegistry`, `hookPipeline`
   - `onTranscriptEntry`: append to transcript, check context budget, compress if needed
9. After each tool dispatch: save checkpoint if tool has side effects.
10. Fire `memoryUpdated` hook on each `saveMemory` call.
11. Guard non-empty result. Append `.assistantMessage(result)`. Set `_status = .completed(result)`.
12. Save final session checkpoint. Return result.

---

## Errors

```swift
public enum ResearchAssistantError: Error, Sendable {
    case emptyGoal
    case noResponseContent
    case sessionTypeMismatch(expected: String, actual: String)
    case sessionCorrupted
    case mcpConnectionFailed(server: String, error: Error)
}
```

MCP connection failures are non-fatal — the agent continues without that server's tools. Session errors are fatal on resume but not on fresh runs.

---

## Transcript Shape

Fresh session:
```
[0] .userMessage("Research Swift concurrency best practices")
[1] .reasoning("Checking memory for prior research on this topic...")
[2] .toolCall(name: "recallMemory", ...)
[3] .toolResult(name: "recallMemory", result: "[]")    ← no prior findings
[4] .toolCall(name: "searchWeb", ...)
[5] .toolResult(name: "searchWeb", result: "[{...}]")
[6] .toolCall(name: "readDocument", ...)
[7] .toolResult(name: "readDocument", result: "...")
[8] .toolCall(name: "saveMemory", ...)                  ← persist finding
[9] .toolResult(name: "saveMemory", result: "saved")
[10] .toolCall(name: "saveCheckpoint", ...)              ← checkpoint session
[11] .toolResult(name: "saveCheckpoint", result: "session-abc123")
... (more research iterations) ...
[N] .toolCall(name: "generateReport", ...)
[N+1] .toolResult(name: "generateReport", result: "# Research Report\n...")
[N+2] .assistantMessage("# Research Report on Swift Concurrency\n...")
```

Resumed session:
```
    — session-abc123 restored (12 entries, step 6) —
    — sessionRestored hook fired —
[12] .reasoning("Resuming research from checkpoint...")
... (continues from step 7) ...
```

---

## Hooks

Subscribes to:
- `sessionSaved` — logs checkpoint creation
- `sessionRestored` — logs session restoration with entry count
- `memoryUpdated` — logs memory entry creation
- `llmRequestSent` — monitors for context budget utilization

---

## Constraints

- Import `SwiftSynapseHarness`; no raw URLSession or OpenAI SDK.
- Session checkpoints must occur after every side-effecting tool call.
- Memory entries must persist beyond the current session.
- MCP connection failures must not prevent the agent from running (degrade gracefully).
- Context budget compression must preserve transcript structural integrity.
- Resumed sessions must validate agent type before restoring.

---

## Success Criteria

1. Empty goal throws `ResearchAssistantError.emptyGoal`.
2. Session saves and restores correctly — transcript and custom state preserved.
3. `sessionTypeMismatch` thrown when resuming a session from a different agent type.
4. Memory entries persist across sessions — `recallMemory` returns findings from prior runs.
5. MCP tools appear in `ToolRegistry` alongside native tools.
6. MCP connection failure does not crash — agent continues with native tools only.
7. Context budget triggers compression at 80% utilization.
8. After compression, transcript integrity is maintained (no orphaned entries).
9. `sessionSaved`, `sessionRestored`, and `memoryUpdated` hooks fire at correct times.

---

## Platforms

iOS 26+, macOS 26+, visionOS 2.4+. Swift 6.2+ strict concurrency.
