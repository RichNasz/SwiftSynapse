<!-- Generated from CodeGenSpecs/Agent-README-Generation.md + Agents/PerformanceOptimizer/specs/SPEC.md — Do not edit manually. -->

# PerformanceOptimizer

Analyze Swift packages for performance bottlenecks, profile code, suggest optimizations, and benchmark alternatives with resilient recovery from context overflow and rate limits.

## Overview

PerformanceOptimizer is the reference implementation for the Resilience trait in SwiftSynapse. It demonstrates recovery chains (context compaction, output token escalation, continuation), rate-limit-aware retries, transcript integrity validation, and graceful shutdown with cleanup handlers. The agent handles large codebases that overflow the context window and recovers from output truncation automatically.

**Patterns used:** RecoveryChain, RateLimitState, RateLimitPolicy, TranscriptIntegrityCheck, GracefulShutdownHandler, SlidingWindowCompressor.

**Platforms:** iOS 26+, macOS 26+, visionOS 2.4+

## Quick Start

**CLI:**

```bash
swift run performance-optimizer "Find and fix the bottleneck in NetworkManager.swift" \
    --server-url http://127.0.0.1:1234/v1/responses \
    --model llama3
```

**Programmatic:**

```swift
import PerformanceOptimizerAgent

let agent = try PerformanceOptimizer(
    configuration: AgentConfiguration(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "llama3"
    )
)
let result = try await agent.execute(goal: "Analyze performance of DataParser.swift")
print(result)
```

**SwiftUI:**

```swift
struct MyView: View {
    @State private var agent = PerformanceOptimizer()

    var body: some View {
        // agent.status and agent.transcript update automatically
    }
}
```

## Input

| Parameter | Type | Description |
|-----------|------|-------------|
| `goal` | `String` | Performance analysis request (e.g., "Find and fix the bottleneck in NetworkManager.swift") |

## Output

| Field | Type | Description |
|-------|------|-------------|
| result | `String` | Performance analysis with profiling data, optimization suggestions, and benchmark comparisons |

## Tools

| Tool | Description | Concurrency Safe |
|------|-------------|-------------------|
| `analyzeProfile` | Reads Instruments trace data and produces a profiling summary | Yes |
| `benchmarkAlternative` | Executes code benchmarks comparing original vs alternative implementations | No (exclusive) |
| `suggestOptimization` | Generates optimized code with explanation for a given issue | Yes |
| `measureMemory` | Produces memory allocation profile (peak, steady-state, allocations/sec) | Yes |
| `compareImplementations` | Side-by-side analysis of multiple code snippets with metrics | Yes |

`benchmarkAlternative` is serialized (`isConcurrencySafe: false`) because it modifies the benchmark workspace. `compareImplementations` may produce very large output that triggers `OutputTokenEscalationStrategy`.

## How It Works

1. Validate `goal` is non-empty; throw `PerformanceOptimizerError.emptyGoal` if empty.
2. Set status to running and append user message to transcript.
3. Configure `RecoveryChain` with three strategies: `ReactiveCompactionStrategy`, `OutputTokenEscalationStrategy`, and `ContinuationStrategy`.
4. Configure `RateLimitState` and `RateLimitPolicy` (respects `Retry-After` headers, max 60s cooldown).
5. Register `GracefulShutdownHandler` with cleanup closures for benchmark workspace and telemetry.
6. Register all 5 tools in `ToolRegistry`.
7. Run `AgentToolLoop.run()` with tool registry, recovery chain, and rate-limit-aware retry.
8. After each recovery operation, validate transcript via `TranscriptIntegrityCheck` and repair if needed.
9. Check `Task.isCancelled` between tool iterations for cooperative cancellation.
10. Guard non-empty result, append assistant message, set status to completed, and return.

## Transcript Example

```
[user]       Analyze performance of DataParser.swift
[toolCall]   analyzeProfile({"filePath": "DataParser.swift"})
[toolResult] analyzeProfile → {hot functions, call counts, durations} (0.5s)
[toolCall]   compareImplementations({"implementations": ["...", "..."]})
[toolResult] compareImplementations → {side-by-side analysis} (0.8s)
[assistant]  Based on the profiling data, the main bottleneck is...
```

With recovery:
```
    — RecoverableError.outputTruncated detected —
    — OutputTokenEscalationStrategy: max_tokens 1024 → 2048 —
    — retry with increased token budget —
[assistant]  Based on the profiling data, the main bottleneck is... (full response)
```

## Testing

```bash
swift test --filter PerformanceOptimizerTests
```

- Empty goal throws `PerformanceOptimizerError.emptyGoal`
- On `contextWindowExceeded`: transcript compresses and retries successfully
- On `outputTruncated`: `max_tokens` escalates and retry produces full output
- On continued truncation after escalation: continuation prompt resumes output
- Rate-limited LLM calls respect `Retry-After` headers
- After compaction, transcript integrity check passes (no orphaned tool calls)
- On SIGTERM: benchmark workspace is cleaned up, no temp files remain
- On task cancellation: `agentCancelled` hook fires, status is `.error`

## Constraints

- Import `SwiftSynapseHarness`; no raw URLSession or OpenAI SDK.
- Recovery chain must try all strategies before propagating errors.
- Rate limit cooldown must not exceed `maxCooldownSeconds` (60s default).
- Transcript integrity must be verified after any recovery operation.
- Graceful shutdown handlers must execute even on cancellation.
- `benchmarkAlternative` is exclusive (`isConcurrencySafe: false`) — serialized execution.

## File Structure

```
Agents/PerformanceOptimizer/
├── README.md
├── specs/
│   ├── SPEC.md
│   └── Overview.md
├── Sources/
│   └── PerformanceOptimizer.swift
├── CLI/
│   └── PerformanceOptimizerCLI.swift
└── Tests/
    └── PerformanceOptimizerTests.swift
```

## License

MIT License — see the root [LICENSE](../../LICENSE) for details.

## Related

- [specs/SPEC.md](specs/SPEC.md) — agent specification
- [specs/Overview.md](specs/Overview.md) — generation rules
- [Root README.md](../../README.md) — project overview
