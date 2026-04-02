# PerformanceOptimizer Agent Specification

> Reference implementation for Resilience trait — recovery chains, rate limiting, transcript integrity, conversation continuation, and graceful shutdown.

## Purpose

Analyze Swift packages for performance bottlenecks, profile code, suggest optimizations, and benchmark alternatives. Handles large codebases that overflow the context window, recovers from output truncation, respects API rate limits, and cleans up profiling artifacts on shutdown.

---

## Configuration

| Parameter       | Type                 | Default | Description |
|-----------------|----------------------|---------|-------------|
| `configuration` | `AgentConfiguration` | —       | Server URL, model, API key, timeout, retries |

---

## Input

| Parameter | Type     | Description |
|-----------|----------|-------------|
| `goal`    | `String` | Performance analysis request (e.g., "Find and fix the bottleneck in NetworkManager.swift") |

---

## Tools (5 tools)

### analyzeProfile
- **Input**: `filePath: String`
- **Output**: JSON profiling summary (hot functions, call counts, durations)
- **Side effects**: Reads Instruments trace data from filesystem
- **`isConcurrencySafe`**: `true`

### benchmarkAlternative
- **Input**: `original: String`, `alternative: String`, `iterations: Int`
- **Output**: JSON benchmark results (mean, median, p95, comparison)
- **Side effects**: Executes code benchmarks (may be long-running)
- **`isConcurrencySafe`**: `false` (modifies benchmark workspace)
- **Note**: Long-running tool — may trigger rate limits on subsequent LLM calls

### suggestOptimization
- **Input**: `code: String`, `issue: String`
- **Output**: Optimized code with explanation
- **Side effects**: None
- **`isConcurrencySafe`**: `true`

### measureMemory
- **Input**: `filePath: String`
- **Output**: Memory allocation profile (peak, steady-state, allocations/sec)
- **Side effects**: Reads from filesystem
- **`isConcurrencySafe`**: `true`

### compareImplementations
- **Input**: `implementations: [String]` (array of code snippets)
- **Output**: Side-by-side analysis with metrics — **potentially very large output** that triggers `OutputTokenEscalationStrategy`
- **Side effects**: None
- **`isConcurrencySafe`**: `true`

---

## Resilience Configuration

### RecoveryChain

```swift
RecoveryChain([
    ReactiveCompactionStrategy(),          // compress transcript on context overflow
    OutputTokenEscalationStrategy(),       // increase max_tokens on truncation (1024 → 2048 → 4096)
    ContinuationStrategy(),                // "Please continue from where you left off"
])
```

The chain is passed to `AgentToolLoop.run()`. On `RecoverableError.contextWindowExceeded`, `ReactiveCompactionStrategy` compresses the transcript using `SlidingWindowCompressor(windowSize: 20)`. On `RecoverableError.outputTruncated`, `OutputTokenEscalationStrategy` doubles `max_tokens` and retries. On continued truncation, `ContinuationStrategy` sends a continuation prompt.

### Rate Limiting

```swift
let rateLimitState = RateLimitState()
let rateLimitPolicy = RateLimitPolicy(
    maxRetries: config.maxRetries,
    respectRetryAfter: true,
    maxCooldownSeconds: 60
)
```

LLM calls use `retryWithRateLimit(state:policy:)` instead of plain `retryWithBackoff`. The `benchmarkAlternative` tool is long-running, so subsequent LLM calls may hit rate limits — the rate-limit-aware retry respects `Retry-After` headers.

### Transcript Integrity

After recovery operations that modify the transcript (compaction, continuation), run `TranscriptIntegrityCheck.validate()` to detect orphaned tool calls/results. If violations are found, repair via `recoverTranscript()` using `DefaultConversationRecoveryStrategy`, and fire the `transcriptRepaired` hook.

---

## Graceful Shutdown

Register cleanup handlers at init:

```swift
shutdownHandler.register {
    // Clean up temporary benchmark workspace
    try? FileManager.default.removeItem(at: benchmarkWorkspace)
}
shutdownHandler.register {
    // Flush any pending telemetry
    await telemetrySink?.flush()
}
```

On `SIGTERM`/`SIGINT`, handlers execute in LIFO order (telemetry flushes first, then workspace cleanup).

On `Task.isCancelled` during tool execution, set `_status = .error(CancellationError())` and fire `agentCancelled` hook before cleanup.

---

## Tasks (execute steps)

1. Validate `goal` is non-empty. Set `_status = .error(PerformanceOptimizerError.emptyGoal)` and throw if empty.
2. Set `_status = .running`. Append `.userMessage(goal)`.
3. Configure `RecoveryChain` with 3 strategies.
4. Configure `RateLimitState` and `RateLimitPolicy`.
5. Register `GracefulShutdownHandler` with cleanup closures.
6. Register all 5 tools in `ToolRegistry`.
7. Run `AgentToolLoop.run()` with:
   - `toolRegistry`, `recoveryChain`, `rateLimitState`
   - `retryWithRateLimit` for LLM calls
   - `onTranscriptEntry`: append to transcript
8. After each recovery: validate transcript via `TranscriptIntegrityCheck`, repair if needed.
9. Check `Task.isCancelled` between tool iterations.
10. Guard non-empty result. Append `.assistantMessage(result)`. Set `_status = .completed(result)`. Return.

---

## Errors

```swift
public enum PerformanceOptimizerError: Error, Sendable {
    case emptyGoal
    case noResponseContent
    case benchmarkFailed(reason: String)
    case profilingUnavailable
}
```

`RecoverableError` variants are handled by `RecoveryChain` — they do not propagate unless all strategies return `.cannotRecover`. `RateLimitError` propagates after exhausting rate-limit retries. Network errors propagate from `LLMClient`.

---

## Transcript Shape (with recovery)

```
[0] .userMessage("Analyze performance of DataParser.swift")
[1] .toolCall(name: "analyzeProfile", ...)
[2] .toolResult(name: "analyzeProfile", ...)
[3] .toolCall(name: "compareImplementations", ...)
[4] .toolResult(name: "compareImplementations", ...)       ← large output
[5] .assistantMessage("Based on the profiling...")         ← truncated
    — RecoverableError.outputTruncated detected —
    — OutputTokenEscalationStrategy: max_tokens 1024 → 2048 —
[6] .assistantMessage("Based on the profiling data, the main bottleneck is...")  ← full response
```

With context overflow:
```
    — RecoverableError.contextWindowExceeded detected —
    — ReactiveCompactionStrategy: compressed 45 entries → 20 via SlidingWindowCompressor —
    — TranscriptIntegrityCheck: 0 violations —
    — retry with compressed transcript —
```

---

## Hooks

Subscribes to:
- `transcriptRepaired` — logs which violations were found and repaired
- `agentCancelled` — triggers graceful shutdown cleanup

---

## Constraints

- Import `SwiftSynapseHarness`; no raw URLSession or OpenAI SDK.
- Recovery chain must try all strategies before propagating errors.
- Rate limit cooldown must not exceed `maxCooldownSeconds` (60s default).
- Transcript integrity must be verified after any recovery operation.
- Graceful shutdown handlers must execute even on cancellation.
- `benchmarkAlternative` is exclusive (`isConcurrencySafe: false`) — serialized execution.

---

## Success Criteria

1. Empty goal throws `PerformanceOptimizerError.emptyGoal`.
2. On `contextWindowExceeded`: transcript compresses and retries successfully.
3. On `outputTruncated`: `max_tokens` escalates and retry produces full output.
4. On continued truncation after escalation: continuation prompt resumes output.
5. Rate-limited LLM calls respect `Retry-After` headers.
6. After compaction, transcript integrity check passes (no orphaned tool calls).
7. On SIGTERM: benchmark workspace is cleaned up, no temp files remain.
8. On task cancellation: `agentCancelled` hook fires, status is `.error`.

---

## Platforms

iOS 26+, macOS 26+, visionOS 2.4+. Swift 6.2+ strict concurrency.
