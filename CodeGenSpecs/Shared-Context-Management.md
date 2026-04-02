# Shared Spec: Context Management

> Core trait (budget) + Resilience trait (advanced compressors) — token budget tracking and transcript compression.

---

## Summary

Context management ensures agents stay within LLM token limits. `ContextBudget` tracks usage against a maximum, and `TranscriptCompressor` implementations reduce transcript size when the budget is exhausted.

---

## Core Types

### ContextBudget

```swift
public struct ContextBudget: Sendable {
    public let maxTokens: Int
    public private(set) var usedTokens: Int
    public var remainingTokens: Int { get }
    public var isExhausted: Bool { get }
    public var utilizationPercentage: Double { get }

    public mutating func record(tokens: Int)
    public mutating func reset()
}
```

### ContextBudgetError

```swift
public enum ContextBudgetError: Error, Sendable {
    case exhausted(used: Int, max: Int)
}
```

### TranscriptCompressor Protocol

```swift
public protocol TranscriptCompressor: Sendable {
    func compress(_ entries: [TranscriptEntry]) -> [TranscriptEntry]
}
```

### CompactionTrigger

```swift
public enum CompactionTrigger: Sendable {
    case threshold(utilizationPercentage: Double)   // e.g., 0.8 = 80%
    case tokenCount(Int)                             // absolute token count
    case entryCount(Int)                             // max transcript entries
    case manual                                      // caller-initiated
}
```

---

## Built-in Compressors (Core Trait)

### SlidingWindowCompressor

Keeps the last N entries, discarding older ones. Simplest strategy.

```swift
public struct SlidingWindowCompressor: TranscriptCompressor {
    public init(windowSize: Int)
}
```

---

## Advanced Compressors (Resilience Trait)

### ImportanceCompressor

Scores entries by importance (tool results > reasoning > user messages) and prunes lowest-scored entries first.

### AutoCompactCompressor

Automatically compresses when a `CompactionTrigger` condition is met.

### MicroCompactor

Aggressive compression that summarizes long tool results and reasoning chains.

### CompositeCompressor

Chains multiple compressors in sequence for layered compression.

```swift
public struct CompositeCompressor: TranscriptCompressor {
    public init(_ compressors: [any TranscriptCompressor])
}
```

---

## Integration Points

- **AgentToolLoop**: checks `ContextBudget` before each LLM call; triggers compression if needed
- **Recovery Strategy**: `ReactiveCompactionStrategy` uses `TranscriptCompressor` when context window is exceeded
- **Session Resume**: budget state is not persisted — recalculated on restore
- **Telemetry**: emits `.contextCompacted` events when compression occurs
