<!-- Generated from CodeGenSpecs/Agent-README-Generation.md + Agents/ResearchAssistant/specs/SPEC.md — Do not edit manually. -->

# ResearchAssistant

Conduct iterative research across multiple sessions with persistent memory, external data sources via MCP, and context window management.

## Overview

ResearchAssistant is the reference implementation for the Persistence trait (session + memory) and MCP trait in SwiftSynapse. It searches the web, reads documents, remembers findings across sessions via persistent memory, connects to external data sources via MCP servers, manages growing context with budget tracking and compression, and produces evolving research reports. Sessions can be resumed from checkpoints, and prior findings are automatically recalled at the start of each run.

**Patterns used:** SessionStore, MemoryStore, MCPManager, ContextBudget, SlidingWindowCompressor, SystemPromptBuilder.

**Platforms:** iOS 26+, macOS 26+, visionOS 2.4+

## Quick Start

**CLI:**

```bash
swift run research-assistant "Research Swift concurrency best practices for iOS 26" \
    --server-url http://127.0.0.1:1234/v1/responses \
    --model llama3
```

Resume a previous session:

```bash
swift run research-assistant "Continue researching Swift concurrency" \
    --session-id session-abc123 \
    --server-url http://127.0.0.1:1234/v1/responses \
    --model llama3
```

**Programmatic:**

```swift
import ResearchAssistantAgent

let agent = try ResearchAssistant(
    configuration: AgentConfiguration(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "llama3"
    )
)
let report = try await agent.execute(goal: "Research Swift concurrency best practices")
print(report)
```

**SwiftUI:**

```swift
struct MyView: View {
    @State private var agent = ResearchAssistant()

    var body: some View {
        // agent.status and agent.transcript update automatically
    }
}
```

## Input

| Parameter | Type | Description |
|-----------|------|-------------|
| `goal` | `String` | Research question or topic (e.g., "Research Swift concurrency best practices for iOS 26") |
| `sessionId` | `String?` | Optional — resume a previous research session |

## Output

| Field | Type | Description |
|-------|------|-------------|
| result | `String` | Research report in Markdown format with findings, sources, and conclusions |

## Tools

| Tool | Description | Concurrency Safe | Side Effects |
|------|-------------|-------------------|--------------|
| `searchWeb` | Searches the web for a query, returns JSON results | Yes | Network request |
| `readDocument` | Extracts text content from a URL | Yes | Network request |
| `saveMemory` | Persists a finding with category and tags to `MemoryStore` | No | Writes to MemoryStore |
| `recallMemory` | Queries `MemoryStore` for matching entries | Yes | Reads from MemoryStore |
| `saveCheckpoint` | Captures current session state to `SessionStore` | No | Writes to SessionStore |
| `generateReport` | Produces a formatted Markdown research report | Yes | None |

## How It Works

1. Validate `goal` is non-empty; throw `ResearchAssistantError.emptyGoal` if empty.
2. If `sessionId` is provided, load and restore the session (validate agent type, restore transcript, decode custom state, fire `sessionRestored` hook).
3. Set status to running and append user message to transcript.
4. Connect MCP servers (if configured) and bridge MCP tools into `ToolRegistry`.
5. Query `MemoryStore` for relevant prior findings and inject them into the system prompt.
6. Initialize `ContextBudget` for tracking token usage across the session.
7. Register all 6 native tools in `ToolRegistry`.
8. Run `AgentToolLoop.run()` with tool registry and hook pipeline; on each transcript entry, check context budget and compress if utilization exceeds 80%.
9. After each side-effecting tool dispatch, save a session checkpoint.
10. Fire `memoryUpdated` hook on each `saveMemory` call.
11. Guard non-empty result, append assistant message, set status to completed.
12. Save final session checkpoint and return the result.

## Transcript Example

Fresh session:

```
[user]       Research Swift concurrency best practices
[toolCall]   recallMemory({"query": "Swift concurrency"})
[toolResult] recallMemory → [] (0.01s)
[toolCall]   searchWeb({"query": "Swift concurrency best practices iOS 26"})
[toolResult] searchWeb → [{title, url, snippet}, ...] (1.2s)
[toolCall]   readDocument({"url": "https://..."})
[toolResult] readDocument → "..." (0.8s)
[toolCall]   saveMemory({"content": "...", "category": "project", "tags": ["concurrency"]})
[toolResult] saveMemory → "saved: mem-001" (0.05s)
[toolCall]   saveCheckpoint({})
[toolResult] saveCheckpoint → "session-abc123" (0.1s)
[toolCall]   generateReport({"topic": "Swift Concurrency", "findings": "..."})
[toolResult] generateReport → "# Research Report..." (0.2s)
[assistant]  # Research Report on Swift Concurrency...
```

Resumed session:

```
    — session-abc123 restored (12 entries, step 6) —
    — sessionRestored hook fired —
[user]       Continue researching Swift concurrency
    ... (continues from checkpoint) ...
```

## Testing

```bash
swift test --filter ResearchAssistantTests
```

- Empty goal throws `ResearchAssistantError.emptyGoal`
- Session saves and restores correctly — transcript and custom state preserved
- `sessionTypeMismatch` thrown when resuming a session from a different agent type
- Memory entries persist across sessions — `recallMemory` returns findings from prior runs
- MCP tools appear in `ToolRegistry` alongside native tools
- MCP connection failure does not crash — agent continues with native tools only
- Context budget triggers compression at 80% utilization
- After compression, transcript integrity is maintained
- `sessionSaved`, `sessionRestored`, and `memoryUpdated` hooks fire at correct times

## Constraints

- Import `SwiftSynapseHarness`; no raw URLSession or OpenAI SDK.
- Session checkpoints must occur after every side-effecting tool call.
- Memory entries must persist beyond the current session.
- MCP connection failures must not prevent the agent from running (degrade gracefully).
- Context budget compression must preserve transcript structural integrity.
- Resumed sessions must validate agent type before restoring.

## File Structure

```
Agents/ResearchAssistant/
├── README.md
├── specs/
│   ├── SPEC.md
│   └── Overview.md
├── Sources/
│   └── ResearchAssistant.swift
├── CLI/
│   └── ResearchAssistantCLI.swift
└── Tests/
    └── ResearchAssistantTests.swift
```

## License

MIT License — see the root [LICENSE](../../LICENSE) for details.

## Related

- [specs/SPEC.md](specs/SPEC.md) — agent specification
- [specs/Overview.md](specs/Overview.md) — generation rules
- [Root README.md](../../README.md) — project overview
