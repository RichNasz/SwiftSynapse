<!-- Generated from CodeGenSpecs/Agent-README-Generation.md + Agents/PRReviewer/specs/SPEC.md — Do not edit manually. -->

# PRReviewer

Analyze code diffs for Swift style, performance, and security issues with guardrails that prevent leaking secrets discovered in code.

## Overview

PRReviewer is the reference implementation for the Safety trait in SwiftSynapse. It demonstrates guardrails, permissions, human-in-the-loop approval, content filtering, result truncation, and streaming tool execution. The agent fetches diffs, analyzes them for style and security issues, and formats a comprehensive review — all while ensuring no secrets, PII, or API keys leak into the final output.

**Patterns used:** GuardrailPipeline, PermissionGate, ApprovalDelegate, ResultTruncator, StreamingToolExecutor, SystemPromptBuilder.

**Platforms:** iOS 26+, macOS 26+, visionOS 2.4+

## Quick Start

**CLI:**

```bash
swift run pr-reviewer "Review PR #42 for style and security issues" \
    --server-url http://127.0.0.1:1234/v1/responses \
    --model llama3
```

**Programmatic:**

```swift
import PRReviewerAgent

let agent = try PRReviewer(
    configuration: AgentConfiguration(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "llama3"
    )
)
let review = try await agent.execute(goal: "Review PR #42 for security issues")
print(review)
```

**SwiftUI:**

```swift
struct MyView: View {
    @State private var agent = PRReviewer()

    var body: some View {
        // agent.status and agent.transcript update automatically
    }
}
```

## Input

| Parameter | Type | Description |
|-----------|------|-------------|
| `goal` | `String` | Natural-language review request (e.g., "Review PR #42 for style and security issues") |

## Output

| Field | Type | Description |
|-------|------|-------------|
| result | `String` | Formatted Markdown code review with findings, suggestions, and patches |

## Tools

| Tool | Description | Concurrency Safe | Permission |
|------|-------------|-------------------|------------|
| `fetchDiff` | Fetches unified diff text from filesystem or API | Yes | `.requiresApproval` for private repos |
| `analyzeSwiftStyle` | Pure analysis producing JSON array of style issues | Yes | Allowed |
| `checkSecurityPatterns` | Pure analysis producing JSON array of security findings | Yes | Allowed |
| `suggestPatch` | Generates a unified diff patch suggestion | Yes | `.denied` for destructive operations |
| `formatReview` | Formats findings and patches into Markdown review | Yes | Allowed |

All tool results pass through `ResultTruncator` (max 2048 tokens, head/tail strategy). `checkSecurityPatterns` output is sanitized by `ContentFilter`. `formatReview` output is evaluated by `GuardrailPipeline`.

## How It Works

1. Validate `goal` is non-empty; throw `PRReviewerError.emptyGoal` if empty.
2. Set status to running and append user message to transcript.
3. Configure `GuardrailPipeline` with `ContentFilter.default` plus custom secret patterns for Swift code.
4. Configure `PermissionGate` with `ToolListPolicy` rules (allow, require approval, deny).
5. Set `ApprovalDelegate` on the permission gate for human-in-the-loop approval.
6. Register all 5 tools in `ToolRegistry`.
7. Build `AgentRequest` with `SystemPromptBuilder` (role, tools, output format at descending priorities).
8. Run `AgentToolLoop.runStreaming()` with tool registry, hook pipeline, permission gate, guardrail pipeline, streaming tool executor, and result truncator.
9. Guard non-empty result, append assistant message, set status to completed, and return.

## Transcript Example

```
[user]       Review PR #42 for security issues
[toolCall]   fetchDiff({"prNumber": 42})
[toolResult] fetchDiff → <truncated diff> (0.3s)
[toolCall]   checkSecurityPatterns({"code": "..."})
[toolCall]   analyzeSwiftStyle({"code": "..."})
[toolResult] checkSecurityPatterns → [{...}] (0.1s)
[toolResult] analyzeSwiftStyle → [{...}] (0.2s)
[toolCall]   formatReview({"findings": "...", "patches": "..."})
[toolResult] formatReview → "## Review Summary..." (0.1s)
[assistant]  ## Code Review for PR #42...
```

Note: `checkSecurityPatterns` and `analyzeSwiftStyle` dispatch concurrently via `StreamingToolExecutor`.

## Testing

```bash
swift test --filter PRReviewerTests
```

- Empty goal throws `PRReviewerError.emptyGoal`
- Guardrail blocks review output containing API keys and fires `guardrailTriggered` hook
- `suggestPatch` with destructive change triggers `ApprovalDelegate`; denied returns `PermissionError.rejected`
- Large diffs are truncated to fit `TruncationPolicy` without context overflow
- Concurrent-safe tools execute in parallel
- Tool results are cached for identical inputs
- Final review contains no secrets, PII, or API keys

## Constraints

- Import `SwiftSynapseHarness`; no raw URLSession or OpenAI SDK.
- All tool results pass through `ResultTruncator` before feeding back to LLM.
- Guardrails evaluate both tool output and LLM responses — no secret can leak to the final review.
- Permission gate must be configured before any tool dispatch.
- `suggestPatch` must never execute without approval for destructive changes.
- Tool result caching is enabled for `analyzeSwiftStyle` and `checkSecurityPatterns`.

## File Structure

```
Agents/PRReviewer/
├── README.md
├── specs/
│   ├── SPEC.md
│   └── Overview.md
├── Sources/
│   └── PRReviewer.swift
├── CLI/
│   └── PRReviewerCLI.swift
└── Tests/
    └── PRReviewerTests.swift
```

## License

MIT License — see the root [LICENSE](../../LICENSE) for details.

## Related

- [specs/SPEC.md](specs/SPEC.md) — agent specification
- [specs/Overview.md](specs/Overview.md) — generation rules
- [Root README.md](../../README.md) — project overview
