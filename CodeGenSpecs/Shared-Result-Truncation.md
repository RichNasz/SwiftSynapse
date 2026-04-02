# Shared Spec: Result Truncation

> Core trait — handling oversized tool results before returning to the LLM.

---

## Summary

When a tool returns a result that exceeds the token budget, the `ResultTruncator` reduces it to fit. This prevents context window overflow from a single large tool result.

---

## Core Types

### TruncationPolicy

```swift
public struct TruncationPolicy: Sendable {
    public let maxTokens: Int           // max tokens per tool result
    public let strategy: TruncationMode
}

public enum TruncationMode: Sendable {
    case headTail(keepHead: Int, keepTail: Int)   // keep first N and last M tokens
    case head(Int)                                  // keep first N tokens
    case summary                                    // summarize (requires LLM call)
}
```

### ResultTruncator

```swift
public struct ResultTruncator: Sendable {
    public init(policy: TruncationPolicy)
    public func truncate(_ result: String) -> String
}
```

---

## Integration Points

- **ToolExecutor / AgentToolLoop**: applies truncation to tool results before feeding back to the LLM
- **Tool Result Budgeting**: works alongside `toolResultBudgetTokens` from `AgentConfiguration`
- **Context Budget**: truncation helps keep overall context within budget
