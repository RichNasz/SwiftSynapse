# Creating Agent Specs for SwiftSynapse

> A comprehensive guide to writing the spec files that code generators use to produce idiomatic SwiftSynapse agents.

---

## Table of Contents

1. [How the Spec-Driven Workflow Works](#1-how-the-spec-driven-workflow-works)
2. [The Two-File Pattern](#2-the-two-file-pattern)
3. [Step 0 — Naming and Folder Setup](#3-step-0--naming-and-folder-setup)
4. [Writing SPEC.md — The Behavioral Contract](#4-writing-specmd--the-behavioral-contract)
   - [4.1 Header](#41-header)
   - [4.2 Goal](#42-goal)
   - [4.3 Configuration](#43-configuration-llm-agents-only)
   - [4.4 Input](#44-input)
   - [4.5 Tasks ⚠ Most Important Section](#45-tasks--most-important-section)
   - [4.6 Tools](#46-tools-tool-using-agents-only)
   - [4.7 Output](#47-output)
   - [4.8 Errors](#48-errors)
   - [4.9 Transcript Shape](#49-transcript-shape)
   - [4.10 Constraints](#410-constraints)
   - [4.11 Success Criteria](#411-success-criteria)
   - [4.12 Platforms](#412-platforms)
5. [Writing Overview.md — The Codegen Contract](#5-writing-overviewmd--the-codegen-contract)
   - [5.1 Header](#51-header)
   - [5.2 Files to Generate](#52-files-to-generate)
   - [5.3 Shared Types Used](#53-shared-types-used)
   - [5.4 Shared Specs to Apply](#54-shared-specs-to-apply)
   - [5.5 Actor State Properties](#55-actor-state-properties)
   - [5.6 Init Rules](#56-init-rules)
   - [5.7 execute() Rules](#57-execute-rules)
   - [5.8 CLI Rules](#58-cli-rules)
   - [5.9 Test Rules](#59-test-rules)
6. [Choosing Traits](#6-choosing-traits)
7. [Tool Design Guide](#7-tool-design-guide)
8. [The Complexity Ladder](#8-the-complexity-ladder)
9. [Pre-Generation Checklist](#9-pre-generation-checklist)
10. [Generating and Verifying](#10-generating-and-verifying)

---

## 1. How the Spec-Driven Workflow Works

SwiftSynapse is a **spec-first** repository. Every `.swift` file — agent sources, CLI runners, test suites — is a generated artifact. You never write implementation code by hand. Instead:

1. You write two spec files describing what the agent should do and how to generate it.
2. A code generator (Claude Code via the `/generate-agent` skill) reads your specs plus 35 shared codegen rules in `CodeGenSpecs/` and produces the Swift files.
3. You run `swift build` and `swift test` to verify. If something is wrong, you **fix the spec and regenerate** — not the generated code.

This discipline exists for a concrete reason: generated code diverges silently. Once a developer hand-edits a generated file, the spec and the code are no longer synchronized. The next regeneration overwrites the manual change. By treating generated files as write-once artifacts, the spec remains the single source of truth — searchable, diffable, and reviewable without understanding Swift syntax.

**The golden rule: if generated code is wrong, fix the spec. Never edit generated files.**

### What the Generator Reads

When you invoke `/generate-agent MyAgent`, the generator reads:

- `Agents/MyAgent/specs/SPEC.md` — your agent's behavioral contract
- `Agents/MyAgent/specs/Overview.md` — your generation recipe
- Every `CodeGenSpecs/*.md` file listed in Overview.md's "Shared Specs to Apply" section

It merges these into a complete picture and emits:

- `Agents/MyAgent/Sources/MyAgent.swift` — the actor
- `Agents/MyAgent/CLI/MyAgentCLI.swift` — the CLI runner
- `Agents/MyAgent/Tests/MyAgentTests.swift` — the test suite

---

## 2. The Two-File Pattern

Every agent has exactly two spec files. Understanding their distinct roles is essential before writing either.

### SPEC.md — The Behavioral Contract

Written from the **user's perspective**. Describes what the agent does, not how to code it. A reader should be able to understand the agent's behavior completely from SPEC.md without knowing Swift.

SPEC.md answers:
- What is this agent for?
- What does it accept as input?
- What steps does it perform?
- What tools does the LLM have access to?
- What can go wrong, and what errors are thrown?
- What does a successful run look like?

SPEC.md is also the product documentation. If you were writing a README for your agent, it would be derived from SPEC.md.

### Overview.md — The Codegen Contract

Written from the **code generator's perspective**. Tells the generator exactly what to emit for this specific agent: file paths, shared APIs to use, which of the 35 shared codegen specs apply, and the precise structure of `init()`, `execute()`, the CLI, and tests.

Overview.md answers:
- Which files should be produced, and where?
- Which shared codegen rules apply (by filename)?
- Which `SwiftSynapseHarness` types does this agent use?
- What are the exact steps in `execute(goal:)`?
- What are the test function names and what does each assert?

### Why Two Files?

Separating behavioral intent from generation recipe means you can:

- **Update behavior** without touching generation rules — change what the agent does without re-specifying how to wire it up.
- **Update generation rules** without touching behavior — if the harness API changes (e.g., a new `AgentToolLoop` signature), you update Overview.md and regenerate without changing the behavioral spec.
- **Review separately** — a product manager can review SPEC.md without understanding codegen internals; a platform engineer can review Overview.md without understanding the agent's business logic.

---

## 3. Step 0 — Naming and Folder Setup

Before writing any specs, establish the scaffolding.

### Naming Convention

Agent names are **PascalCase noun phrases** that describe what the agent does:

| Good | Avoid |
|------|-------|
| `PRReviewer` | `ReviewPR`, `review_pr` |
| `DataPipelineAgent` | `Pipeline`, `DataAgent` |
| `TaskPlanner` | `PlanTask`, `task-planner` |
| `ResearchAssistant` | `Researcher`, `AssistResearch` |

Append `Agent` only when the name would otherwise be ambiguous (e.g., `DataPipelineAgent` not just `DataPipeline`).

### Create the Directory Structure

```
Agents/
└── MyAgent/
    ├── specs/
    │   ├── SPEC.md         ← you write this
    │   └── Overview.md     ← you write this
    ├── Sources/            ← generator will write here
    ├── CLI/                ← generator will write here
    └── Tests/              ← generator will write here
```

The `Sources/`, `CLI/`, and `Tests/` directories should exist but be empty. The generator will not create directories — only write files into existing ones.

### Register in Package.swift

Add three targets to `Package.swift`. Follow the exact pattern of existing agents:

```swift
// Library — the agent's public API
.target(
    name: "MyAgentAgent",
    dependencies: ["SwiftSynapseHarness"],
    path: "Agents/MyAgent/Sources"
),

// CLI executable
.executableTarget(
    name: "my-agent",
    dependencies: [
        "MyAgentAgent",
        .product(name: "ArgumentParser", package: "swift-argument-parser")
    ],
    path: "Agents/MyAgent/CLI"
),

// Test suite
.testTarget(
    name: "MyAgentTests",
    dependencies: ["MyAgentAgent", "SwiftSynapseHarness"],
    path: "Agents/MyAgent/Tests"
),
```

**Naming rules:**
- Library target: `<AgentName>Agent` (note the double "Agent" suffix for agents named `*Agent`)
- Executable target: `<kebab-case-name>` (e.g., `MyAgent` → `my-agent`, `PRReviewer` → `pr-reviewer`)
- Test target: `<AgentName>Tests`

Also add the library to the `products` array if it should be importable by other targets (e.g., the dashboard):

```swift
.library(name: "MyAgentAgent", targets: ["MyAgentAgent"]),
```

---

## 4. Writing SPEC.md — The Behavioral Contract

Use `Agents/TemplateAgent/specs/SPEC.md` as your starting point. Walk through every section below.

### 4.1 Header

```markdown
# Agent Spec: MyAgent

> One sentence that captures what this agent does and why it exists.
```

**What to write:** The agent name as an H1, followed by a blockquote with a single crisp sentence. Think of this as the elevator pitch.

**Why the generator needs it:** The description becomes the doc comment on the generated actor and the `--help` summary in the CLI.

**Examples:**
- ✅ `> Reference implementation for tool-using agents. Demonstrates @LLMTool macro usage, the full tool dispatch loop, and concurrent-safe tool scheduling.`
- ✅ `> Analyze code diffs for Swift style, performance, and security issues.`
- ❌ `> This agent does things with LLMs.` (too vague — the generator can't produce meaningful documentation)

---

### 4.2 Goal

```markdown
## Goal

Forward a user prompt to an Open Responses API-compatible endpoint and return the model's reply.
```

**What to write:** One to two sentences at the highest level of abstraction. No implementation details, no API names, no Swift syntax.

**Why the generator needs it:** The goal becomes the system prompt's first sentence and the basis for the CLI's purpose description. It also guides the generator when it must make decisions not explicitly stated elsewhere in the spec.

**Common mistake:** Mixing goal with implementation: `"Call _llmClient.send() and return response.firstOutputText"` — this belongs in the Tasks section, not here.

---

### 4.3 Configuration (LLM Agents Only)

```markdown
## Configuration

| Parameter       | Type                 | Default | Description                         |
|-----------------|----------------------|---------|-------------------------------------|
| `configuration` | `AgentConfiguration` | —       | Server URL, model, API key, timeout |
```

**What to write:** A table showing the agent's configuration parameters. For most LLM agents, this is a single row pointing to `AgentConfiguration`. Note any agent-specific configuration beyond the standard fields — there are rarely any.

**Why the generator needs it:** This tells the generator the agent requires an `init(configuration: AgentConfiguration) throws` signature, uses `config.buildLLMClient()` or `config.buildClient()`, and derives all tuning parameters (URL, model, retries, timeouts) from `AgentConfiguration`.

**Omit this section entirely** for non-LLM agents (like `SimpleEcho`) — its absence tells the generator not to generate an `AgentConfiguration` init.

**`AgentConfiguration` standard fields** (no need to redocument these — just reference the type):
- `serverURL` — Open Responses API endpoint
- `modelName` — model identifier
- `apiKey` — optional authentication token
- `timeoutSeconds` — request/resource timeout (default: 300)
- `maxRetries` — retry attempts for transient errors (default: 3, range: 1–10)
- `toolResultBudgetTokens` — max tokens for tool results fed back to LLM (default: 4096)

---

### 4.4 Input

```markdown
## Input

| Field  | Type     | Description                          |
|--------|----------|--------------------------------------|
| `goal` | `String` | The natural-language request to fulfill |
```

**What to write:** A table listing every parameter the agent's `execute(goal:)` method receives. All agents receive `goal: String` as the primary input. If your agent's `execute` method has additional parameters (rare — most customization goes through `AgentConfiguration`), list them here.

**Why the generator needs it:** The generator validates that `goal` is non-empty as the first step in `execute()`. The description becomes the parameter's documentation comment.

---

### 4.5 Tasks ⚠ Most Important Section

```markdown
## Tasks

1. Validate `goal` is non-empty; set `_status = .error(MyAgentError.emptyGoal)` and throw if empty.
2. Set `_status = .running`; call `_transcript.reset()`; append `.userMessage(goal)`.
3. Build a client via `config.buildLLMClient()`.
4. Wrap the LLM call in `retryWithBackoff(maxAttempts: config.maxRetries)`:
   - Build a `ResponseRequest` with `RequestTimeout(300)` and `ResourceTimeout(300)`.
   - Call `try await agent.send(request)`; extract text via `response.firstOutputText`.
5. Guard that the result is non-empty; throw `MyAgentError.noResponseContent` if empty.
6. Append `.assistantMessage(result)`.
7. Set `_status = .completed(result)` and return the result string.
```

**What to write:** A numbered list where **each item maps to one logical unit of generated code**. This is the most critical section in SPEC.md. The generator reads it sequentially and produces corresponding Swift code for each step.

Be specific about:

| Element | Vague (bad) | Specific (good) |
|---------|-------------|-----------------|
| Status transitions | "Set status" | "`_status = .running`" |
| Transcript appends | "Log the message" | "Append `.userMessage(goal)` to `_transcript`" |
| Error throwing | "Throw if empty" | "Set `_status = .error(MyAgentError.emptyGoal)` and throw" |
| LLM call | "Call the LLM" | "Call `try await agent.send(request)`, extract via `response.firstOutputText`" |
| Tool dispatch | "Run the tools" | "Call `AgentToolLoop.run(client:config:goal:tools:transcript:maxIterations:hooks:)` with `maxIterations: 10`" |
| Retry | "Retry on failure" | "Wrap in `retryWithBackoff(maxAttempts: config.maxRetries)`; call `agent.reset()` before each attempt" |

**Why the generator needs it:** The Tasks section IS the `execute(goal:)` function body, expressed in natural language. Every missing step is missing code. Every vague step is code the generator will have to guess at — and it may guess wrong.

**The status-before-throw invariant:** Always set `_status = .error(...)` on the line immediately before every `throw`. This is a hard requirement — failing to specify it here means the generated code may not set error status before throwing.

**Transcript append rules:**
- `.userMessage(goal)` — always the first append, immediately after `_status = .running`
- `.assistantMessage(result)` — always the last append, immediately before `_status = .completed`
- `.toolCall(name:arguments:)` / `.toolResult(name:result:duration:)` — added automatically by `AgentToolLoop`; don't describe these in Tasks unless you're doing manual tool dispatch

---

### 4.6 Tools (Tool-Using Agents Only)

```markdown
## Tools

### Calculate

Tool name (macro-derived): `calculate`

```swift
/// Evaluates a basic arithmetic expression and returns the result as a Double.
@LLMTool
public struct Calculate: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "A math expression using +, -, *, /. Example: '144 / 12'")
        var expression: String
    }
    public static var isConcurrencySafe: Bool { true }
    public func call(arguments: Arguments) async throws -> ToolOutput { ... }
}
```

Implementation: sanitize `expression` to safe characters `[0-9+\-*/. ()]`; evaluate with `NSExpression`. If the sanitized string is empty or evaluation fails, throw `MyAgentError.toolCallFailed("calculate")`. Return `ToolOutput(content: "\(result.doubleValue)")`.

- `isConcurrencySafe: true` — pure function, no side effects
```

**What to write:** One subsection per tool, each containing:

1. **Tool name (macro-derived):** The snake_case name the LLM will call. Derived from the struct name: `AnalyzeSwiftStyle` → `analyze_swift_style`. State it explicitly so both you and the generator agree.

2. **Doc comment:** Written as an imperative instruction that the LLM reads. This becomes the tool's `description` field in the JSON schema. Write it to tell the LLM exactly when to call this tool and what it returns.

3. **Full `@LLMTool` struct signature:** Include every argument with its type and `@LLMToolGuide` annotation. Use `...` for the `call` body — the implementation is described separately. This signature is what the generator emits verbatim.

4. **Implementation description:** What `call(arguments:)` actually does. Focus on: validation, computation, error cases, and return format. The generator translates this into Swift code.

5. **`isConcurrencySafe` and reason:** Required. States whether the tool can run in parallel with other concurrent-safe tools.

6. **Permission level** (if applicable): `.requiresApproval`, `.denied`, etc. — only for Safety-trait agents.

7. **Guardrail behavior** (if applicable): What happens if the tool output triggers a guardrail — only for Safety-trait agents.

**Why the generator needs it:** Tool structs are generated verbatim from this specification. The LLM's understanding of what tools it has, when to call them, and what arguments to pass comes entirely from the generated tool schema. A vague or incomplete tool spec produces a broken schema that leads to incorrect tool calls.

**`@LLMToolGuide` constraint annotations:**

| Annotation | Use for | Example |
|------------|---------|---------|
| `description:` | All arguments | `@LLMToolGuide(description: "The file path to analyze.")` |
| `.range(n...m)` | Int with bounds | `@LLMToolGuide(description: "...", .range(1...100))` |
| `.doubleRange(n...m)` | Double with bounds | `@LLMToolGuide(description: "...", .doubleRange(0.0...1.0))` |
| `.anyOf([...])` | String enum | `@LLMToolGuide(description: "...", .anyOf(["sum", "avg", "count"]))` |
| `.count(n...m)` | Array length | `@LLMToolGuide(description: "...", .count(1...10))` |
| `.minimumCount(n)` | Array minimum length | `@LLMToolGuide(description: "...", .minimumCount(1))` |

---

### 4.7 Output

```markdown
## Output

The LLM's final answer as a `String`. Example: `"144 divided by 12 equals 12."`
```

**What to write:** What the agent returns on successful completion. Usually `String`. For agents with structured output, describe the format (JSON, Markdown, etc.). Include a brief example.

**Why the generator needs it:** The return type of `execute(goal:)` and the format the CLI uses to print results.

---

### 4.8 Errors

```markdown
## Errors

```swift
public enum MyAgentError: Error, Sendable {
    case emptyGoal               // goal was ""
    case noResponseContent       // LLM returned an empty response
    case toolCallFailed(String)  // carries the tool name
    case unknownTool(String)     // LLM called a tool that wasn't registered
}
```
```

**What to write:** The complete error enum declaration, exactly as it will appear in generated code. Every case with its associated values (if any) and a comment stating when it is thrown.

**Why the generator needs it:** The error enum is emitted verbatim. A missing case is a missing error case in the generated Swift. If a case needs an associated value (e.g., `case diffTooLarge(path: String)`), write it with the label — associated value labels become part of the Swift API.

**Standard cases every LLM agent should include:**
- `case emptyGoal` — thrown by `execute()` when goal is `""` (note: `AgentLifecycleError.emptyGoal` is what `run(goal:)` throws before calling `execute()`)
- `case noResponseContent` — thrown when the LLM returns an empty string

**Do not confuse agent errors with harness errors.** These propagate automatically without being listed here:
- `AgentConfigurationError` — invalid URL, empty model name, out-of-range maxRetries
- `AgentLifecycleError` — empty goal caught by macro-generated `run(goal:)`
- `GuardrailError` — blocked output (Safety trait)
- `PermissionError` — denied tool call (Safety trait)

---

### 4.9 Transcript Shape

```markdown
## Transcript Shape

Minimum (LLM answers directly without tool calls):
```
[0] .userMessage("What is 144 / 12?")
[1] .assistantMessage("144 divided by 12 equals 12.")
```

Typical (one tool call):
```
[0] .userMessage("What is 144 / 12?")
[1] .toolCall(name: "calculate", arguments: "{\"expression\":\"144/12\"}")
[2] .toolResult(name: "calculate", result: "12.0", duration: 0.002s)
[3] .assistantMessage("144 divided by 12 equals 12.")
```

Concurrent tools (two dispatched simultaneously):
```
[0] .userMessage("...")
[1] .toolCall(name: "analyzeSwiftStyle", arguments: "...")
[2] .toolCall(name: "checkSecurityPatterns", arguments: "...")
[3] .toolResult(name: "analyzeSwiftStyle", result: "...", duration: 0.1s)
[4] .toolResult(name: "checkSecurityPatterns", result: "...", duration: 0.05s)
[5] .assistantMessage("...")
```
```

**What to write:** Example `[TranscriptEntry]` arrays for the minimum case and the typical case. Use the real `TranscriptEntry` enum syntax. Show all cases your agent might produce, including concurrent tool dispatch if applicable.

**Why the generator needs it:** Live integration test assertions check `entries.count >= N`. Unit tests verify specific entry types and ordering. Without an explicit transcript shape, the generator produces vague test assertions or guesses the wrong count.

**Rules for transcript shape:**
- `toolCall` and `toolResult` entries for concurrent-safe tools: all `toolCall` entries appear before all corresponding `toolResult` entries (they're dispatched together, results arrive in completion order)
- `AgentToolLoop` adds `.toolCall` and `.toolResult` entries automatically — don't list them in Tasks
- Streaming agents add entries through `appendDelta()` rather than `append()` — the final shape looks the same, but mention streaming in the Notes

---

### 4.10 Constraints

```markdown
## Constraints

- Must not make any LLM calls (SimpleEcho example)
- Must not persist user data beyond the session
- All tool results pass through `ResultTruncator` before feeding back to LLM
- `suggestPatch` must never execute without approval for destructive changes
- Tool result caching is enabled for `analyzeSwiftStyle` and `checkSecurityPatterns`
```

**What to write:** Hard rules the agent must never violate. These are things the generator will actively add safety checks for, or things the generator will actively omit.

**Why the generator needs it:** Constraints inform exclusions and inclusions the generator can't infer from Tasks alone. "Must not persist user data" tells the generator to omit session/checkpoint code even if the agent does something that looks like persistence. "Tool results must pass through ResultTruncator" tells the generator to add truncation even though Tasks doesn't explicitly list it as a step.

**Common constraints to specify:**
- Data persistence rules ("must not persist beyond session" vs. "must checkpoint every N turns")
- LLM call limits ("at most 3 LLM calls per invocation")
- Concurrency rules ("tools must not share mutable state")
- Safety rules ("no secrets may appear in formatted output")
- API restrictions ("must use Open Responses API only — no Chat Completions endpoint")

---

### 4.11 Success Criteria

```markdown
## Success Criteria

- [x] Status is `.completed` after a successful run
- [x] Transcript contains at least 2 entries (user + assistant) on success
- [x] Throws `MyAgentError.emptyGoal` when goal is `""`
- [x] Status is `.error` after throwing
- [x] `Calculate` tool returns `"4.0"` for input `"2+2"`
- [x] `ConvertUnit` tool throws for unknown units
- [x] Empty transcript after init
```

**What to write:** A checkbox list where every item is a testable, unambiguous assertion. Avoid subjective or vague criteria.

**Why the generator needs it:** Each criterion maps directly to a test case in the generated `Tests/<AgentName>Tests.swift`. The generator reads this list and produces one `@Test` function per criterion. Vague criteria produce vague tests; precise criteria produce precise tests.

**Criterion quality checklist:**
- ✅ Has a specific expected value or type: `"4.0"`, `.completed`, `.error`
- ✅ Specifies which input triggers the behavior
- ✅ Is achievable without a live LLM server (for unit tests) or explicitly noted as a live test
- ❌ "Should work correctly" — untestable
- ❌ "Handles edge cases" — too vague

**Mark live-only criteria clearly:**
```markdown
- [x] _(live)_ Returns a non-empty result for any non-empty goal (requires `SWIFTSYNAPSE_LIVE_TESTS`)
```

---

### 4.12 Platforms

```markdown
## Platforms

iOS 26+, macOS 26+, visionOS 2.4+. Swift 6.2+ strict concurrency.
```

**What to write:** Copy this line verbatim for every agent. If your agent targets only macOS (e.g., a CLI-only tool), note that too.

---

## 5. Writing Overview.md — The Codegen Contract

Use `Agents/TemplateAgent/specs/Overview.md` as your starting point.

### 5.1 Header

```markdown
# Code Generation Overview: MyAgent

> Instructs the code generator on what files to produce and how to assemble them from SPEC.md and shared CodeGenSpecs.
```

The description line can stay as the template text — it's a permanent description of what Overview.md files do.

---

### 5.2 Files to Generate

```markdown
## Files to Generate

| File | Target | Purpose |
|------|--------|---------|
| `Sources/MyAgent.swift` | `MyAgentAgent` library | Error enum + tool structs + agent actor |
| `CLI/MyAgentCLI.swift` | `my-agent` executable | ArgumentParser CLI runner |
| `Tests/MyAgentTests.swift` | `MyAgentTests` test target | Swift Testing suite |
```

**What to write:** One row per file. The File column must match the actual path under `Agents/MyAgent/`. The Target column must match what you registered in `Package.swift`.

**Additional files** — add rows when needed:

| Scenario | Additional file | Purpose |
|----------|-----------------|---------|
| Large tool set | `Sources/MyAgent+Tools.swift` | Tool definitions separated from actor |
| Background tasks | `Sources/MyAgent+Background.swift` | Background-specific extensions |

**Why the generator needs it:** The generator writes files to exact paths. If this table says `Sources/MyAgent.swift` but the Package.swift target points to `Sources/`, the generator writes correctly. If you list a file the generator doesn't expect to produce, it won't produce it. This table is the generator's file manifest.

---

### 5.3 Shared Types Used

```markdown
## Shared Types Used

- `@SpecDrivenAgent` macro — generates `_status`, `_transcript`, `status`, `transcript`, `run(goal:)`
- `AgentConfiguration` — centralized config with validation
- `@LLMTool` / `@LLMToolArguments` / `@LLMToolGuide` — macro stack for tool schema generation
- `AgentLLMTool` — protocol; only `call(arguments:) -> ToolOutput` is required
- `ToolRegistry` — registers tools and dispatches calls
- `AgentToolLoop.run()` — full tool dispatch loop
- `AgentConfigurationError` — config validation errors
```

**What to write:** A bullet list of every type from `SwiftSynapseHarness` that appears in generated code. Don't list types you're not using — extra entries may confuse the generator into importing unnecessary things.

**Core types (always present for LLM agents):**
- `@SpecDrivenAgent`
- `AgentConfiguration`
- `AgentConfigurationError`

**Add for tool-using agents:**
- `@LLMTool`, `@LLMToolArguments`, `@LLMToolGuide`
- `AgentLLMTool`
- `ToolOutput`
- `ToolRegistry`
- `AgentToolLoop`

**Add for Safety trait:**
- `GuardrailPipeline`, `GuardrailPolicy`, `ContentFilter`
- `PermissionGate`, `ToolListPolicy`, `ApprovalDelegate`
- `ResultTruncator`, `TruncationPolicy`

**Add for Resilience trait:**
- `retryWithBackoff`
- `RateLimitState`, `retryWithRateLimit`
- `RecoveryChain`

**Add for Hooks trait:**
- `AgentHookPipeline`, `ClosureHook`

**Add for Observability trait:**
- `TelemetrySink`, `CostTracker`, `CostTrackingTelemetrySink`

**Add for Persistence trait:**
- `AgentSession`, `MemoryStore`, `MemoryEntry`

**Add for MultiAgent trait:**
- `CoordinationRunner`, `SubagentRunner`

**Add for MCP trait:**
- `MCPManager`, `MCPToolBridge`

**Add for Plugins trait:**
- `AgentPlugin`, `PluginManager`, `PluginContext`

**Why the generator needs it:** This is the generator's import and API reference. It uses this list to know which specific harness types to wire up. Listing `AgentToolLoop` but not `ToolRegistry` will produce broken code — both are required for tool dispatch.

---

### 5.4 Shared Specs to Apply

```markdown
## Shared Specs to Apply

1. `Shared-Configuration.md` — `AgentConfiguration` init pattern
2. `Shared-Tool-Registry.md` — `@LLMTool` + `AgentLLMTool` + `ToolRegistry`
3. `Shared-Agent-Tool-Loop.md` — `AgentToolLoop.run()` invocation
4. `Shared-Tool-Concurrency.md` — `isConcurrencySafe` classification
5. `Shared-Error-Strategy.md` — error enum placement, status-before-throw invariant
```

**What to write:** A numbered list of the `CodeGenSpecs/*.md` filenames the generator should apply to this agent. These are the shared rules that fine-tune generated code beyond what SPEC.md and Overview.md describe directly.

**Always include:**
- `Shared-Configuration.md`
- `Shared-Error-Strategy.md`

**Include based on features used:**

| Feature | Required shared spec(s) |
|---------|------------------------|
| LLM call (non-streaming) | `Shared-LLM-Client.md` |
| LLM call (streaming) | `Shared-LLM-Client.md`, `Shared-Streaming-Tool-Executor.md` |
| Tools | `Shared-Tool-Registry.md`, `Shared-Agent-Tool-Loop.md`, `Shared-Tool-Concurrency.md` |
| Retry | `Shared-Retry-Strategy.md` |
| Guardrails | `Shared-Guardrails.md` |
| Permissions | `Shared-Permission-System.md` |
| Hooks | `Shared-Hook-System.md` |
| Result truncation | `Shared-Result-Truncation.md` |
| Tool result caching | `Shared-Caching.md` |
| System prompt builder | `Shared-System-Prompt-Builder.md` |
| Rate limiting | `Shared-Rate-Limiting.md` |
| Recovery chains | `Shared-Recovery-Strategy.md` |
| Cost tracking | `Shared-Cost-Tracking.md` |
| Telemetry | `Shared-Telemetry.md` |
| Session resume | `Shared-Session-Resume.md` |
| Cross-session memory | `Shared-Memory-System.md` |
| Subagents | `Shared-Multi-Agent-Coordination.md` |
| MCP servers | `Shared-MCP-Support.md` |
| Plugins | `Shared-Plugin-System.md` |
| Background execution | `Shared-Background-Execution.md` |
| Graceful shutdown | `Shared-Graceful-Shutdown.md` |
| VCR testing | `Shared-VCR-Testing.md` |

**Why the generator needs it:** The generator reads only the shared specs you list here. Rules in unlisted specs are not applied. If you use `retryWithBackoff` in your Tasks section but don't list `Shared-Retry-Strategy.md` here, the generator may call it with wrong arguments or skip it entirely.

---

### 5.5 Actor State Properties

```markdown
## Actor State Properties

```swift
@SpecDrivenAgent
public actor MyAgent {
    private let config: AgentConfiguration
    private static let maxToolIterations = 10
}
```
```

**What to write:** The actor declaration with all stored properties listed. The `@SpecDrivenAgent` macro generates `_status`, `_transcript`, `status`, `transcript`, `run(goal:)`, `_client`, `_telemetrySink`, and their configure methods — do not list those. List only properties you're adding.

**Standard additional properties for LLM agents:**
- `private let config: AgentConfiguration` — always present
- `private static let maxToolIterations = 10` — for tool-using agents

**Additional properties for advanced agents:**
- Hook pipelines: `public private(set) var hooks: AgentHookPipeline?`
- Permission gates: `private let permissionGate: PermissionGate`
- Guardrail pipelines: `private let guardrailPipeline: GuardrailPipeline`
- Agent-specific state: anything your `execute()` function needs across calls

**For non-LLM agents** (like `SimpleEcho`): no stored properties beyond macro defaults.

---

### 5.6 Init Rules

```markdown
## Init Rules

1. Primary init takes `AgentConfiguration` (already validated by the time it reaches `init`).
2. Stores config as `self.config`.
3. No eager validation — `buildClient()` is called in `execute()`, not `init`.
```

**What to write:** A numbered list of what `init(configuration:)` does step by step. For simple agents, this is 1–3 lines. For complex agents (PRReviewer), this includes configuring subsystems.

**Common init patterns:**

For a basic LLM agent:
```
1. Takes `AgentConfiguration`. Stores as `self.config`.
```

For a tool-using agent with hooks:
```
1. Takes `AgentConfiguration`. Stores as `self.config`.
2. Sets up `AgentHookPipeline` with logging hooks for `preToolUse`, `postToolUse`, and `llmResponseReceived`.
3. Stores hook pipeline as `self.hooks`.
```

For a safety agent:
```
1. Takes `AgentConfiguration`. Stores as `self.config`.
2. Configures `GuardrailPipeline` with `ContentFilter.default` + custom secret patterns.
3. Configures `PermissionGate` with `ToolListPolicy` rules.
4. Registers all 5 tools in `ToolRegistry`.
5. Builds `AgentHookPipeline` with `guardrailTriggered`, `preToolUse`, `postToolUse` hooks.
```

**For non-LLM agents:** "No init — `SimpleEcho()` uses the macro-generated default init with no parameters."

**Why the generator needs it:** The generator produces the `init` method body from this list. Missing steps produce an incomplete initializer.

---

### 5.7 execute() Rules

```markdown
## execute() Rules

1. Guard non-empty goal → `_status = .error(MyAgentError.emptyGoal)` + throw.
2. `_status = .running`; `_transcript.reset()`; append `.userMessage(goal)`.
3. Build `ToolRegistry`; register `Calculate()`, `ConvertUnit()`, `FormatNumber()`.
4. Call `AgentToolLoop.run(client: config.buildClient(), config: config, goal: goal, tools: tools, transcript: _transcript, maxIterations: Self.maxToolIterations, hooks: hooks)`.
5. Guard non-empty result → throw `MyAgentError.noResponseContent`.
6. `_status = .completed(result)`; return result.
```

**What to write:** The numbered list that directly generates the `execute(goal:)` function body. This mirrors SPEC.md Tasks but uses exact API call names.

**Critical API distinctions the generator uses:**

| Scenario | Correct call |
|----------|-------------|
| Simple LLM, no tools | `config.buildLLMClient()` |
| Tool dispatch loop | `config.buildClient()` |
| Non-streaming tool loop | `AgentToolLoop.run(...)` |
| Streaming tool loop | `AgentToolLoop.runStreaming(...)` |
| Retry wrapping | `retryWithBackoff(maxAttempts: config.maxRetries) { ... }` |

**Why the generator needs it:** This is the primary recipe for the `execute(goal:)` method. The generator follows it step by step. Unlike SPEC.md Tasks (which are written in user-facing language), execute() Rules use precise API call names that the generator emits verbatim.

---

### 5.8 CLI Rules

```markdown
## CLI Rules

Uses `AgentConfiguration.fromEnvironment(overrides:)` — `--server-url` and `--model` are optional,
falling back to `SWIFTSYNAPSE_SERVER_URL` and `SWIFTSYNAPSE_MODEL` environment variables.
```

**What to write:** A sentence or two covering:
1. Configuration sourcing (`fromEnvironment(overrides:)` — same for every agent)
2. Any agent-specific CLI flags (e.g., `--diff-path` for PRReviewer)
3. Any special delegate needed (e.g., terminal `ApprovalDelegate` for permission-gated agents)

**Standard CLI flags** (generated for all LLM agents, no need to specify):
- `--server-url` — overrides `SWIFTSYNAPSE_SERVER_URL`
- `--model` — overrides `SWIFTSYNAPSE_MODEL`
- `--api-key` — overrides `SWIFTSYNAPSE_API_KEY`

**Custom CLI flags** (specify when needed):
- `--diff-path <path>` for agents that read local files
- `--session-id <id>` for agents with session resume
- `--dry-run` for agents with permission gates

---

### 5.9 Test Rules

```markdown
## Test Rules

1. `myAgentInitThrowsOnInvalidURL` — invalid URL (`":::not-a-url"`) → `AgentConfigurationError`
2. `myAgentThrowsOnEmptyGoal` — empty goal → `AgentLifecycleError` (thrown by `run(goal:)`)
3. `myAgentInitialStateIsIdle` — `.idle` status, empty transcript after init
4. `calculateToolReturnsResult` — `Calculate().call(arguments: .init(expression: "2+2"))` → content `"4.0"`
5. `calculateToolInvalidExpressionThrows` — invalid expression → `MyAgentError.toolCallFailed`
6. `myAgentLiveResponse` — (live, gated by `SWIFTSYNAPSE_LIVE_TESTS`) non-empty result, `.completed` status
```

**What to write:** A numbered list of test function names with one-line descriptions of what each test asserts. These become `@Test func <name>()` functions in the generated test file.

**Standard tests for every LLM agent** (required — always include these three):
1. `<agentName>InitThrowsOnInvalidURL` — `AgentConfiguration(serverURL: ":::not-a-url", ...)` → `AgentConfigurationError`
2. `<agentName>ThrowsOnEmptyGoal` — `agent.run(goal: "")` → `AgentLifecycleError` (not your agent's error — `run()` catches it first)
3. `<agentName>InitialStateIsIdle` — fresh agent: status `.idle`, transcript empty

**Tool unit tests** — one per tool, testing the happy path and at least one error case:
- Name pattern: `<toolName>Tool<WhatItTests>`
- Test by calling `MyTool().call(arguments: .init(...))` and asserting `.content`

**Live integration test** — always the last item:
- Name: `<agentName>LiveResponse`
- Gated by `ProcessInfo.processInfo.environment["SWIFTSYNAPSE_LIVE_TESTS"] != nil`
- Asserts non-empty result and `.completed` status

**Important:** The empty goal test expects `AgentLifecycleError.self`, not your agent's error type. The `@SpecDrivenAgent` macro generates `run(goal:)` which validates the goal before calling `execute()`, throwing `AgentLifecycleError.emptyGoal`. Your agent's `emptyGoal` case in the error enum guards against direct `execute()` calls.

---

## 6. Choosing Traits

SwiftSynapse uses a trait system to compose capabilities. Each trait adds a set of shared specs and harness types. Start with the lowest-complexity trait set that satisfies your requirements and add traits only when you need them.

| Trait | What It Adds | Activates Shared Spec(s) | Demo Agent |
|-------|-------------|--------------------------|------------|
| **Core** | Observable state, LLM client, tool registry, transcript, config, error strategy | `Shared-Configuration.md`, `Shared-LLM-Client.md`, `Shared-Tool-Registry.md`, `Shared-Agent-Tool-Loop.md`, `Shared-Error-Strategy.md` | All agents |
| **Hooks** | 16 lifecycle events (preToolUse, postToolUse, llmResponseReceived, guardrailTriggered, etc.) with `AgentHookPipeline` and `ClosureHook` | `Shared-Hook-System.md` | PRReviewer |
| **Safety** | `GuardrailPipeline` for secret/PII detection, `PermissionGate` with `ToolListPolicy` for tool access control, `ApprovalDelegate` for human-in-the-loop | `Shared-Guardrails.md`, `Shared-Permission-System.md` | PRReviewer |
| **Resilience** | `retryWithBackoff` for transient LLM errors, `RateLimitState` for rate limiting, `RecoveryChain` for conversation compaction and escalation | `Shared-Retry-Strategy.md`, `Shared-Rate-Limiting.md`, `Shared-Recovery-Strategy.md` | RetryingLLMChatAgent, PerformanceOptimizer |
| **Observability** | `TelemetrySink` with 12 event types, `CostTracker` with per-model pricing, `CostTrackingTelemetrySink` | `Shared-Telemetry.md`, `Shared-Cost-Tracking.md` | TaskPlanner |
| **Persistence** | `AgentSession` for snapshot/resume, `MemoryStore` + `MemoryEntry` for cross-session memory | `Shared-Session-Resume.md`, `Shared-Memory-System.md` | ResearchAssistant |
| **MultiAgent** | `CoordinationRunner` for orchestration, `SubagentRunner` for parallel subagents, shared team memory | `Shared-Multi-Agent-Coordination.md` | TaskPlanner |
| **MCP** | `MCPManager` and `MCPToolBridge` for connecting to external Model Context Protocol tool servers over stdio, SSE, or WebSocket | `Shared-MCP-Support.md` | ResearchAssistant |
| **Plugins** | `AgentPlugin`, `PluginManager`, `PluginContext` for runtime-loadable capabilities without recompilation | `Shared-Plugin-System.md` | DataPipelineAgent |

**Decision guide:**

- **Hooks** — add when you need structured logging, metrics, or event-driven side effects on tool calls and LLM responses. Not needed for simple agents that log to stdout.
- **Safety** — add when the agent processes user-supplied code or content that may contain secrets, PII, or potentially harmful instructions. Also add when the agent's tools can make irreversible changes (file deletion, database writes) that should require human approval.
- **Resilience** — add when calling a remote LLM endpoint that experiences transient failures, rate limits, or slow cold starts. Add recovery chains when conversations can grow too long for the context window.
- **Observability** — add when you need to track API costs, emit structured metrics, or feed telemetry into an external system.
- **Persistence** — add when the agent's work spans multiple invocations, the user needs to resume a session, or findings should be remembered across separate runs.
- **MultiAgent** — add when the task is too large for a single LLM context or when sub-tasks can be parallelized by separate specialized agents.
- **MCP** — add when the agent needs to interact with external tool servers (filesystem access, database queries, web search) through the standardized Model Context Protocol.
- **Plugins** — add when the set of capabilities needs to be extensible at runtime without recompiling the agent, or when different deployments need different tool sets.

---

## 7. Tool Design Guide

### When to Add Tools

Tools are actions the **LLM decides to call**. They are not steps that always run — those belong in Tasks.

Add a tool when:
- The action is discrete and optional (the LLM might or might not need it)
- The action can be called multiple times with different arguments
- The action has deterministic output for a given input
- You want the LLM to be able to chain multiple tools together

Do NOT add a tool when:
- The action always happens (put it in Tasks)
- The action is a one-time initialization (put it in Init Rules)
- The action is purely internal plumbing (no LLM involvement)

### Tool Naming

The struct name is PascalCase; the tool name (as the LLM sees it) is the macro-derived snake_case conversion:

| Struct Name | LLM-visible tool name |
|-------------|----------------------|
| `Calculate` | `calculate` |
| `ConvertUnit` | `convert_unit` |
| `AnalyzeSwiftStyle` | `analyze_swift_style` |
| `FetchDiff` | `fetch_diff` |
| `GeneratePipelineReport` | `generate_pipeline_report` |

Choose names that form natural English verb phrases: "the model will call `analyze_swift_style`".

### The Doc Comment Is the LLM's Instruction

```swift
/// Analyzes a Swift code snippet for style violations and returns a JSON array of findings.
@LLMTool
public struct AnalyzeSwiftStyle: AgentLLMTool {
```

The doc comment becomes the tool's `description` in the generated JSON schema — it is exactly what the LLM reads when deciding whether to call this tool. Write it as an imperative that tells the LLM:
- When to call the tool
- What arguments to pass (briefly)
- What the output contains

Bad: `/// Analyzes code.`
Good: `/// Analyzes a Swift source file for style issues. Returns a JSON array where each item has "line" (Int), "severity" ("warning" | "error"), and "message" (String).`

### Argument Design Principles

**One argument per conceptual input.** Don't bundle unrelated inputs into a JSON string argument — give each one its own typed property.

```swift
// ❌ Poor — forces the LLM to construct JSON manually
@LLMToolGuide(description: "JSON object with 'code' and 'issue' fields")
var params: String

// ✅ Good — typed, self-documenting
@LLMToolGuide(description: "The code to analyze.")
var code: String
@LLMToolGuide(description: "Description of the suspected issue.")
var issue: String
```

**Use strong types.** Prefer `Int` over `String` for counts, `[String]` over comma-separated strings for arrays, `Double` over `String` for numbers.

**Add constraint annotations for every bounded value.** The constraint is part of the schema and prevents the LLM from passing out-of-range values:

```swift
@LLMToolGuide(description: "Maximum results to return.", .range(1...20))
var maxResults: Int

@LLMToolGuide(description: "Aggregation operation.", .anyOf(["sum", "avg", "count", "min", "max"]))
var operation: String
```

**Write descriptions as if the LLM is reading them** — because it is. Be precise about format and units:

```swift
// ❌ Unhelpful
@LLMToolGuide(description: "The value")
var value: Double

// ✅ Helpful
@LLMToolGuide(description: "The numeric value to convert, in the units specified by fromUnit.")
var value: Double
```

### `isConcurrencySafe`

Set to `true` only when the tool is a **pure function**: same input always produces the same output, no side effects, no shared mutable state.

```swift
// ✅ Pure — safe to run in parallel
public static var isConcurrencySafe: Bool { true }   // Calculate, ConvertUnit, AnalyzeSwiftStyle

// ❌ Has side effects — must run sequentially
public static var isConcurrencySafe: Bool { false }  // SaveMemory, WriteFile, NetworkRequest
```

When the LLM requests multiple concurrent-safe tools simultaneously, `AgentToolLoop` dispatches them in parallel. When it requests concurrent-safe and concurrent-unsafe tools together, the unsafe tool runs after all concurrent-safe tools complete.

### ToolOutput

All tool `call(arguments:)` methods return `ToolOutput`:

```swift
return ToolOutput(content: someString)
```

`content` is what the LLM receives as the tool's result. Keep it:
- **Concise** — large results waste context tokens
- **Structured** — JSON is preferable for data the LLM needs to parse
- **Specific** — include only what the LLM needs for its next decision

For large results (file contents, diffs, search results), add `ResultTruncator` via the Safety trait to prevent context overflow.

---

## 8. The Complexity Ladder

Identify where your agent falls on this ladder before writing specs. Start at the lowest level that satisfies your requirements — you can always add traits later by updating the spec and regenerating.

| Level | Pattern | Traits Needed | Reference Agent |
|-------|---------|---------------|-----------------|
| 1 | Pure Swift logic, no LLM | Core only (no config) | `SimpleEcho` |
| 2 | Single LLM call, no tools | Core | `LLMChat` |
| 3 | LLM call with automatic retry | Core + Resilience | `RetryingLLMChatAgent` |
| 4 | Multi-step LLM pipeline (sequential calls) | Core | `LLMChatPersonas` |
| 5 | Token-by-token streaming response | Core | `StreamingChatAgent` |
| 6 | LLM + tool dispatch loop | Core | `ToolUsingAgent` |
| 7 | LLM + skills from agentskills.io catalog | Core + Skills | `SkillsEnabledAgent` |
| 8 | Tools + guardrails + permission gates | Core + Safety + Hooks | `PRReviewer` |
| 9 | Tools + resilience + rate limiting | Core + Resilience | `PerformanceOptimizer` |
| 10 | Tools + session persistence + MCP servers | Core + Persistence + MCP | `ResearchAssistant` |
| 11 | Subagent coordination + cost tracking | Core + MultiAgent + Observability | `TaskPlanner` |
| 12 | Runtime-extensible plugin architecture | Core + Plugins | `DataPipelineAgent` |

**Practical advice:**
- If your agent calls an LLM and returns a response, start at Level 2.
- If it needs to call tools, start at Level 6.
- Only add Safety (Level 8) if you're handling untrusted content or destructive operations.
- Levels 10–12 require substantial spec detail — study the reference agent's specs before writing your own.

---

## 9. Pre-Generation Checklist

Run through this checklist before invoking the code generator. Every unchecked box is a likely generation defect.

### SPEC.md

**Header and Goal**
- [ ] Agent name is PascalCase
- [ ] Blockquote summary is a single clear sentence
- [ ] Goal section is 1–2 sentences at the right level of abstraction (no API names)

**Configuration**
- [ ] Present for LLM agents, absent for non-LLM agents

**Input**
- [ ] `goal` row is present
- [ ] All additional parameters are documented

**Tasks**
- [ ] Every step is numbered and specific enough to generate code
- [ ] Every guard condition names the exact error thrown
- [ ] Every status transition (`_status = .running`, `.completed`, `.error(...)`) is explicit
- [ ] Every transcript append is explicit (`.userMessage`, `.assistantMessage`)
- [ ] Tool dispatch step names the exact `AgentToolLoop` method
- [ ] Status-before-throw invariant is followed for every error path

**Tools** (if applicable)
- [ ] Every tool has a doc comment
- [ ] Every tool has the full `@LLMTool` struct with `@LLMToolArguments`
- [ ] Every argument has `@LLMToolGuide(description:)` with optional constraint
- [ ] Every tool states `isConcurrencySafe`
- [ ] Every tool's implementation is described (not just the signature)

**Errors**
- [ ] `emptyGoal` case is present
- [ ] `noResponseContent` case is present for LLM agents
- [ ] All agent-specific error cases are listed with throw conditions
- [ ] Associated value labels are included where needed

**Transcript Shape**
- [ ] Minimum case is shown
- [ ] Typical case (with tool calls) is shown for tool-using agents
- [ ] Entry types use real enum syntax (`.userMessage`, `.assistantMessage`, `.toolCall`, `.toolResult`)

**Constraints, Success Criteria, Platforms**
- [ ] At least 3 constraints
- [ ] Every success criterion is a concrete testable assertion
- [ ] Platform line is present

---

### Overview.md

**Files to Generate**
- [ ] Every file in the table matches a Package.swift target
- [ ] File paths are relative to `Agents/<AgentName>/`

**Shared Types Used**
- [ ] `@SpecDrivenAgent` is listed
- [ ] Every type used in generated code is listed
- [ ] No extra types are listed that won't appear in generated code

**Shared Specs to Apply**
- [ ] `Shared-Configuration.md` is listed (LLM agents)
- [ ] `Shared-Error-Strategy.md` is listed
- [ ] All trait-specific specs are listed (see Section 5.4 table)

**Actor State Properties**
- [ ] `@SpecDrivenAgent` decorator is shown
- [ ] `config: AgentConfiguration` is listed (LLM agents)
- [ ] All additional stored properties are listed

**Init Rules**
- [ ] Describes what happens in `init` beyond storing `config`
- [ ] Lists any subsystem configuration (guardrails, permissions, hooks)

**execute() Rules**
- [ ] Step 1 is the empty-goal guard
- [ ] Step 2 sets `_status = .running` and resets transcript
- [ ] Tool registry setup is listed before `AgentToolLoop.run()` call
- [ ] `AgentToolLoop.run()` is listed with correct method name (`.run` vs `.runStreaming`)
- [ ] Result guard is listed
- [ ] `_status = .completed` is listed

**Test Rules**
- [ ] `InitThrowsOnInvalidURL` test is listed
- [ ] `ThrowsOnEmptyGoal` test is listed (expects `AgentLifecycleError`)
- [ ] `InitialStateIsIdle` test is listed
- [ ] One test per tool (happy path + error case)
- [ ] Live integration test is listed (gated by `SWIFTSYNAPSE_LIVE_TESTS`)

---

### Package.swift

- [ ] Library target added as `<AgentName>Agent`
- [ ] Executable target added as `<kebab-case>`
- [ ] Test target added as `<AgentName>Tests`
- [ ] All three targets depend on `SwiftSynapseHarness`
- [ ] Library is added to `products` array (if exposed publicly)

---

## 10. Generating and Verifying

### Invoking the Generator

With both spec files written and Package.swift updated, open Claude Code and run:

```
/generate-agent MyAgent
```

The generator will:
1. Read `Agents/MyAgent/specs/SPEC.md`
2. Read `Agents/MyAgent/specs/Overview.md`
3. Read all `CodeGenSpecs/*.md` files listed in your Overview.md
4. Produce `Sources/MyAgent.swift`, `CLI/MyAgentCLI.swift`, `Tests/MyAgentTests.swift`

### Verify: Build

```bash
swift build
```

A clean build means the generated code is syntactically valid. If there are compile errors:

1. Read the error carefully — it points to the generated file and line
2. Determine what in the spec caused the defect (missing type, wrong API name, incomplete step)
3. Fix the spec
4. Regenerate with `/generate-agent MyAgent`
5. **Do not edit the generated file directly**

### Verify: Unit Tests

```bash
swift test
```

All tests should pass without a live server. The unit tests exercise:
- Init validation
- Empty goal rejection
- Tool `call(arguments:)` implementations
- Transcript state after init

If tests fail, the spec's Test Rules or Success Criteria did not match the generated implementation. Fix the spec and regenerate.

### Verify: Live Tests

With a running Open Responses API endpoint:

```bash
SWIFTSYNAPSE_LIVE_TESTS=1 swift test
```

Or test the CLI directly:

```bash
.build/debug/my-agent "Your goal here" \
  --server-url http://127.0.0.1:1234 \
  --model nvidia/nemotron-3-nano-4b
```

Live tests validate that the agent produces meaningful output against a real LLM. If the live test fails:
- `noResponseContent` — the model completed tool iterations without generating a closing text response. This is a model capability issue for small models on complex tasks. The live test can catch this gracefully (see PRReviewer and TaskPlanner live tests for the pattern).
- Wrong transcript entry count — the model may return reasoning tokens as additional `.reasoning` entries. Use `>= N` instead of `== N` for entry count assertions in the live test.

### The Spec-First Principle

If at any point you are tempted to edit a generated file instead of the spec, stop and ask: "What is wrong with the spec that produced this code?" Fix that. Regenerate. The generated file is a symptom; the spec is the root.

The only exception is a genuine harness bug — where the generated code is correct per the spec, but the harness behaves unexpectedly. In that case, file an issue and work around it at the spec level until the harness is fixed.

---

## Reference Files

| File | Purpose |
|------|---------|
| `Agents/TemplateAgent/specs/SPEC.md` | Blank SPEC.md template |
| `Agents/TemplateAgent/specs/Overview.md` | Blank Overview.md template |
| `Agents/SimpleEcho/specs/` | Simplest complete example (no LLM) |
| `Agents/LLMChat/specs/` | Simplest LLM example |
| `Agents/ToolUsingAgent/specs/` | Canonical tool dispatch example |
| `Agents/PRReviewer/specs/` | Most complete example (Safety + Hooks) |
| `Agents/ResearchAssistant/specs/` | Persistence + MCP example |
| `Agents/TaskPlanner/specs/` | MultiAgent + Observability example |
| `CodeGenSpecs/Overview.md` | Index and descriptions of all 35 shared specs |
| `Package.swift` | Existing target declarations to use as pattern |
