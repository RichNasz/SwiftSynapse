# Shared Spec: Caching

> Core trait — LRU/FIFO tool result caching with TTL.

---

## Summary

Tool result caching avoids redundant tool executions when the same tool is called with identical arguments. Cached results are returned instantly, reducing latency and API costs.

---

## Core Types

### CachePolicy

```swift
public struct CachePolicy: Sendable {
    public let maxEntries: Int
    public let ttl: Duration              // time-to-live per entry
    public let evictionStrategy: EvictionStrategy
}
```

### EvictionStrategy

```swift
public enum EvictionStrategy: Sendable {
    case lru    // least recently used (default)
    case fifo   // first in, first out
}
```

---

## Usage

Caching is configured at the `ToolRegistry` level. When enabled, the registry checks the cache before dispatching a tool call. Cache keys are derived from `(toolName, argumentsJSON)`.

---

## Rules

- Only tools marked as `isConcurrencySafe: true` are eligible for caching (side-effecting tools must not be cached).
- Cache entries expire after `ttl` regardless of access pattern.
- Cache is in-memory only — not persisted across sessions.
- When the cache is full, entries are evicted per the configured strategy.
