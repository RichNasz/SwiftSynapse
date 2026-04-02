# Code Generation Overview: ResearchAssistant

> Instructs the code generator on what files to produce and how to assemble them from SPEC.md and shared CodeGenSpecs.

---

## Files to Generate

| File | Target | Purpose |
|------|--------|---------|
| `Sources/ResearchAssistant.swift` | `ResearchAssistantAgent` library | Main actor + error enum + ResearchState |
| `Sources/ResearchAssistant+Tools.swift` | `ResearchAssistantAgent` library | Tool implementations |
| `CLI/ResearchAssistantCLI.swift` | `research-assistant` executable | ArgumentParser CLI with --resume option |
| `Tests/ResearchAssistantTests.swift` | `ResearchAssistantTests` test target | Swift Testing suite |

---

## Shared Types Used

- `AgentConfiguration` — centralized config
- `AgentToolProtocol` / `ToolRegistry` — typed tool registration
- `AgentToolLoop.run()` — tool dispatch loop
- `AgentSession` / `SessionStore` / `FileSessionStore` / `CodableTranscriptEntry` — session persistence
- `MemoryStore` / `FileMemoryStore` / `MemoryEntry` / `MemoryCategory` — cross-session memory
- `MCPManager` / `MCPToolBridge` / `MCPServerConfig` / `StdioMCPTransport` — external data sources
- `ContextBudget` — token budget tracking
- `SlidingWindowCompressor` — transcript compression
- `SystemPromptBuilder` — inject prior memories into system prompt
- `AgentHookPipeline` / `ClosureHook` — session/memory lifecycle hooks
- `@SpecDrivenAgent` macro — generates observable state

---

## Shared Specs to Apply

1. `Shared-Configuration.md` — `AgentConfiguration` init
2. `Shared-Session-Resume.md` — `AgentSession` save/restore/resume contract
3. `Shared-Memory-System.md` — `MemoryStore`, `MemoryEntry`, categories
4. `Shared-MCP-Support.md` — `MCPManager` connection, `MCPToolBridge` registration
5. `Shared-Context-Management.md` — `ContextBudget` tracking, `SlidingWindowCompressor`
6. `Shared-System-Prompt-Builder.md` — inject prior memories into prompt
7. `Shared-Agent-Tool-Loop.md` — `AgentToolLoop.run()` with transcript callbacks
8. `Shared-Hook-System.md` — `sessionSaved`, `sessionRestored`, `memoryUpdated`
9. `Shared-Tool-Registry.md` — tool conformances
10. `Shared-Error-Strategy.md` — error enum, status-before-throw

---

## Actor State Properties

```swift
@SpecDrivenAgent
public actor ResearchAssistant {
    private let config: AgentConfiguration
    private let sessionStore: SessionStore
    private let memoryStore: MemoryStore
    private let mcpManager: MCPManager
    private let hookPipeline: AgentHookPipeline
    private let toolRegistry: ToolRegistry
    private var contextBudget: ContextBudget
    private var currentSessionId: String
    private var currentStep: Int
}
```

---

## Init Rules

1. Primary init takes `AgentConfiguration` + optional `SessionStore`, `MemoryStore`, `[MCPServerConfig]`.
2. Defaults to `FileSessionStore` and `FileMemoryStore` if not provided.
3. Connects MCP servers and bridges tools into `ToolRegistry`.

---

## execute() Rules

1. If resuming: load session, validate type, restore transcript and state.
2. Query memory for prior findings, inject into system prompt.
3. Run tool loop with context budget monitoring.
4. Checkpoint after each side-effecting tool call.
5. Compress transcript when budget > 80%.
6. Save final checkpoint on completion.

---

## CLI Rules

Uses `AgentConfiguration.fromEnvironment(overrides:)`. Includes `--resume <session-id>` option. Includes `--mcp-server` option for MCP configuration.

---

## Test Rules

1. `researchAssistantThrowsOnEmptyGoal` — empty goal error
2. `researchAssistantSavesAndRestoresSession` — round-trip session persistence
3. `researchAssistantSessionTypeMismatch` — wrong agent type on resume
4. `researchAssistantMemoryPersistsAcrossSessions` — save then recall
5. `researchAssistantMCPToolsBridged` — MCP tools appear in registry
6. `researchAssistantMCPFailureGraceful` — continues without failed server
7. `researchAssistantContextBudgetCompression` — triggers at 80%
8. `researchAssistantHooksFire` — session/memory hooks fire correctly
