# Code Generation Overview: PerformanceOptimizer

> Instructs the code generator on what files to produce and how to assemble them from SPEC.md and shared CodeGenSpecs.

---

## Files to Generate

| File | Target | Purpose |
|------|--------|---------|
| `Sources/PerformanceOptimizer.swift` | `PerformanceOptimizerAgent` library | Main actor + error enum |
| `Sources/PerformanceOptimizer+Tools.swift` | `PerformanceOptimizerAgent` library | Tool implementations |
| `CLI/PerformanceOptimizerCLI.swift` | `performance-optimizer` executable | ArgumentParser CLI |
| `Tests/PerformanceOptimizerTests.swift` | `PerformanceOptimizerTests` test target | Swift Testing suite |

---

## Shared Types Used

- `AgentConfiguration` — centralized config
- `AgentToolProtocol` / `ToolRegistry` — typed tool registration
- `AgentToolLoop.run()` — tool dispatch loop with recovery integration
- `RecoveryChain` / `ReactiveCompactionStrategy` / `OutputTokenEscalationStrategy` / `ContinuationStrategy` — self-healing
- `RateLimitState` / `RateLimitPolicy` / `retryWithRateLimit` — rate-limit-aware retry
- `TranscriptIntegrityCheck` / `recoverTranscript` — post-recovery validation
- `GracefulShutdownHandler` — LIFO cleanup
- `SlidingWindowCompressor` — transcript compaction
- `AgentHookPipeline` / `ClosureHook` — `transcriptRepaired`, `agentCancelled` hooks
- `@SpecDrivenAgent` macro — generates observable state

---

## Shared Specs to Apply

1. `Shared-Configuration.md` — `AgentConfiguration` init
2. `Shared-Recovery-Strategy.md` — `RecoveryChain` with 3 strategies
3. `Shared-Rate-Limiting.md` — `retryWithRateLimit` wrapping LLM calls
4. `Shared-Conversation-Integrity.md` — post-recovery transcript validation
5. `Shared-Graceful-Shutdown.md` — cleanup handlers
6. `Shared-Context-Management.md` — `SlidingWindowCompressor` for compaction
7. `Shared-Agent-Tool-Loop.md` — `AgentToolLoop.run()` with recovery chain
8. `Shared-Hook-System.md` — `transcriptRepaired`, `agentCancelled`
9. `Shared-Tool-Registry.md` — tool conformances
10. `Shared-Error-Strategy.md` — error enum, status-before-throw

---

## Actor State Properties

```swift
@SpecDrivenAgent
public actor PerformanceOptimizer {
    private let config: AgentConfiguration
    private let recoveryChain: RecoveryChain
    private let rateLimitState: RateLimitState
    private let shutdownHandler: GracefulShutdownHandler
    private let hookPipeline: AgentHookPipeline
    private let toolRegistry: ToolRegistry
}
```

---

## Init Rules

1. Primary init takes `AgentConfiguration`.
2. Builds `RecoveryChain` with 3 strategies.
3. Creates `RateLimitState` and registers shutdown handlers.

---

## execute() Rules

1. Guard non-empty goal.
2. Run `AgentToolLoop.run()` with recovery chain and rate-limit-aware retry.
3. After each recovery: validate transcript integrity, repair if needed.
4. Check `Task.isCancelled` between iterations.
5. Guard non-empty result; set status; return.

---

## CLI Rules

Uses `AgentConfiguration.fromEnvironment(overrides:)`. Includes `--file` option for target Swift file.

---

## Test Rules

1. `perfOptimizerThrowsOnEmptyGoal` — empty goal error
2. `perfOptimizerRecoveryOnContextOverflow` — compaction + retry succeeds
3. `perfOptimizerEscalatesOnTruncation` — max_tokens doubled
4. `perfOptimizerContinuationOnRepeatedTruncation` — continuation prompt sent
5. `perfOptimizerRespectsRateLimit` — waits for Retry-After before retrying
6. `perfOptimizerTranscriptIntegrityAfterCompaction` — no orphaned entries
7. `perfOptimizerGracefulShutdownCleansUp` — temp files removed on SIGTERM
8. `perfOptimizerCancellationFiresHook` — `agentCancelled` hook fires
