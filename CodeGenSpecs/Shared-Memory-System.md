# Shared Spec: Memory System

> Persistence trait — cross-session agent memory for recall and learning.

---

## Summary

The memory system allows agents to store and recall information across sessions. Unlike session persistence (which snapshots the full agent state), memory stores discrete entries categorized by purpose. Agents can build up knowledge over time.

---

## Core Types

### MemoryCategory

```swift
public enum MemoryCategory: Sendable, Hashable {
    case user           // information about the user
    case feedback       // corrections and preferences
    case project        // project context and decisions
    case reference      // external resource pointers
    case custom(String) // agent-specific categories
}
```

### MemoryEntry

```swift
public struct MemoryEntry: Identifiable, Codable, Sendable {
    public let id: UUID
    public let category: MemoryCategory
    public let content: String
    public let tags: [String]
    public let createdAt: Date
    public var lastAccessedAt: Date
}
```

### MemoryStore Protocol

```swift
public protocol MemoryStore: Sendable {
    func save(_ entry: MemoryEntry) async throws
    func load(category: MemoryCategory?) async throws -> [MemoryEntry]
    func delete(id: UUID) async throws
    func search(query: String) async throws -> [MemoryEntry]
}
```

### FileMemoryStore

```swift
public actor FileMemoryStore: MemoryStore {
    public init(directory: URL)
}
```

Default file-based implementation. Stores entries as JSON files in the specified directory.

---

## Integration Points

- **Hooks**: fires `memoryUpdated` event when entries are saved or deleted
- **Session Persistence**: memory is independent of session state — persists across sessions
- **Multi-Agent**: `TeamMemory` (see `Shared-Multi-Agent-Coordination.md`) is for runtime coordination; `MemoryStore` is for persistent cross-session recall
- If the Persistence trait is disabled, memory operations compile to no-op stubs.
