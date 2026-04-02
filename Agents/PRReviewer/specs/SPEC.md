# PRReviewer Agent Specification

> Reference implementation for Safety trait — guardrails, permissions, human-in-the-loop approval, content filtering, result truncation, and streaming tool execution.

## Purpose

Analyze code diffs for Swift style, performance, and security issues. Guardrails prevent leaking secrets discovered in code. Permission gates require human approval before suggesting destructive changes (file deletions, force-unwrap removals). Tool results are truncated to fit context. Tools dispatch concurrently during streaming.

---

## Configuration

| Parameter       | Type                 | Default | Description |
|-----------------|----------------------|---------|-------------|
| `configuration` | `AgentConfiguration` | —       | Server URL, model, API key, timeout, retries |

---

## Input

| Parameter | Type     | Description |
|-----------|----------|-------------|
| `goal`    | `String` | Natural-language review request (e.g., "Review PR #42 for style and security issues") |

---

## Tools (5 tools)

### fetchDiff
- **Input**: `prNumber: Int` or `diffPath: String`
- **Output**: Unified diff text (potentially large — subject to `ResultTruncator`)
- **Side effects**: Reads from filesystem or API
- **`isConcurrencySafe`**: `true`
- **Permission**: `.requiresApproval` for private repos (configurable via `ToolListPolicy`)

### analyzeSwiftStyle
- **Input**: `code: String`
- **Output**: JSON array of style issues (line, severity, message)
- **Side effects**: None (pure analysis)
- **`isConcurrencySafe`**: `true`

### checkSecurityPatterns
- **Input**: `code: String`
- **Output**: JSON array of security findings (pattern, line, risk level)
- **Side effects**: None
- **`isConcurrencySafe`**: `true`
- **Guardrail**: Output evaluated by `ContentFilter` to sanitize detected secrets before returning to LLM

### suggestPatch
- **Input**: `file: String`, `issue: String`, `suggestion: String`
- **Output**: Unified diff patch
- **Side effects**: None (generates suggestion only)
- **`isConcurrencySafe`**: `true`
- **Permission**: `.denied` for destructive operations (file deletion, removing safety checks)

### formatReview
- **Input**: `findings: String` (JSON), `patches: String` (JSON)
- **Output**: Formatted Markdown review
- **Side effects**: None
- **`isConcurrencySafe`**: `true`
- **Guardrail**: Output evaluated by `GuardrailPipeline` — blocks if PII, API keys, or secrets are present in the formatted review

---

## Safety Configuration

### GuardrailPipeline

```
ContentFilter.default          — credit cards, SSNs, API keys
+ CustomSecretPattern          — matches common Swift secret patterns (let apiKey =, password:, token =)
+ CodeBlockSecretDetector      — scans fenced code blocks for hardcoded credentials
```

Guardrails evaluate:
- Tool arguments before dispatch (`GuardrailInput.toolArguments`)
- LLM output before appending to transcript (`GuardrailInput.llmOutput`)

On `.block`: throw `GuardrailError.blocked`, set status `.error`, fire `guardrailTriggered` hook.
On `.sanitize`: replace content with sanitized version and continue.
On `.warn`: log warning, fire `guardrailTriggered` hook, continue.

### PermissionGate

```
ToolListPolicy.allow("analyzeSwiftStyle", "checkSecurityPatterns", "formatReview")
ToolListPolicy.requireApproval("fetchDiff")         — for private repo access
ToolListPolicy.deny("suggestPatch")                  — when suggestion involves deletion
```

When `suggestPatch` is called with a destructive suggestion (detected by checking if the patch removes more than 50% of a file), the permission gate overrides to `.requiresApproval` and invokes the `ApprovalDelegate`.

### ApprovalDelegate

The CLI provides a terminal-based `ApprovalDelegate` that prints the tool name, arguments summary, and reason, then waits for y/n input. The SwiftUI dashboard provides a dialog-based delegate.

---

## Tasks (execute steps)

1. Validate `goal` is non-empty. Set `_status = .error(PRReviewerError.emptyGoal)` and throw if empty.
2. Set `_status = .running`. Append `.userMessage(goal)`.
3. Configure `GuardrailPipeline` with `ContentFilter.default` + custom secret patterns.
4. Configure `PermissionGate` with `ToolListPolicy` rules.
5. Set `ApprovalDelegate` on the permission gate.
6. Register all 5 tools in `ToolRegistry`.
7. Build `AgentRequest` with `SystemPromptBuilder`:
   - Priority 100: Role ("You are a Swift code reviewer...")
   - Priority 50: Available tools and their purposes
   - Priority 30: Output format requirements
8. Run `AgentToolLoop.runStreaming()` with:
   - `toolRegistry`, `hookPipeline`, `permissionGate`, `guardrailPipeline`
   - `StreamingToolExecutor` for concurrent tool dispatch during streaming
   - `ResultTruncator` with `TruncationPolicy(maxTokens: 2048, strategy: .headTail(keepHead: 1024, keepTail: 512))`
   - `onStreamEvent`: update transcript with streaming deltas
9. Guard non-empty result. Append `.assistantMessage(result)`. Set `_status = .completed(result)`. Return.

---

## Errors

```swift
public enum PRReviewerError: Error, Sendable {
    case emptyGoal
    case noResponseContent
    case diffTooLarge(path: String)
}
```

`GuardrailError.blocked` and `PermissionError.denied`/`.rejected` propagate from the safety layer. Network errors propagate from `LLMClient`.

---

## Transcript Shape

```
[0] .userMessage("Review PR #42 for security issues")
[1] .toolCall(name: "fetchDiff", arguments: "{\"prNumber\": 42}")
[2] .toolResult(name: "fetchDiff", result: "<truncated diff>", duration: 0.3s)
[3] .toolCall(name: "checkSecurityPatterns", arguments: "{\"code\": \"...\"}")
[4] .toolCall(name: "analyzeSwiftStyle", arguments: "{\"code\": \"...\"}")
[5] .toolResult(name: "checkSecurityPatterns", result: "[{...}]", duration: 0.1s)
[6] .toolResult(name: "analyzeSwiftStyle", result: "[{...}]", duration: 0.2s)
[7] .toolCall(name: "formatReview", arguments: "{...}")
[8] .toolResult(name: "formatReview", result: "## Review Summary...", duration: 0.1s)
[9] .assistantMessage("## Code Review for PR #42\n...")
```

Note: `checkSecurityPatterns` and `analyzeSwiftStyle` dispatch concurrently (both `isConcurrencySafe: true`) via `StreamingToolExecutor`.

---

## Hooks

Subscribes to:
- `guardrailTriggered` — logs which guardrail activated and the decision
- `llmResponseReceived` — monitors for secret patterns in raw LLM output
- `preToolUse` / `postToolUse` — logs tool dispatch timing

---

## Constraints

- Import `SwiftSynapseHarness`; no raw URLSession or OpenAI SDK.
- All tool results pass through `ResultTruncator` before feeding back to LLM.
- Guardrails evaluate both tool output and LLM responses — no secret can leak to the final review.
- Permission gate must be configured before any tool dispatch.
- `suggestPatch` must never execute without approval for destructive changes.
- Tool result caching is enabled for `analyzeSwiftStyle` and `checkSecurityPatterns` (same code input = same analysis).

---

## Success Criteria

1. Empty goal throws `PRReviewerError.emptyGoal`.
2. Guardrail blocks review output containing API keys — `guardrailTriggered` hook fires.
3. `suggestPatch` with destructive change triggers `ApprovalDelegate` — denied returns `PermissionError.rejected`.
4. Large diffs are truncated to fit `TruncationPolicy` — no context overflow.
5. Concurrent-safe tools (`analyzeSwiftStyle`, `checkSecurityPatterns`) execute in parallel.
6. Tool results are cached — second analysis of same code returns instantly.
7. Final review contains no secrets, PII, or API keys.

---

## Platforms

iOS 26+, macOS 26+, visionOS 2.4+. Swift 6.2+ strict concurrency.
