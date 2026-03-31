# Agent Spec: SimpleEcho

> First proof-of-concept agent. Validates the spec-to-codegen pipeline with the simplest possible agent.

---

## Goal

Echo user input back with a prefix. No LLM calls, no tools, no background execution.

---

## Input

| Field | Type | Description |
|-------|------|-------------|
| goal | String | The user-provided text to echo back |

---

## Tasks

1. Validate that `goal` is non-empty; set status to `.error(SimpleEchoError.emptyGoal)` and throw if empty.
2. Set status to `.running`.
3. Append a `.userMessage` transcript entry with the goal text.
4. Produce the echoed string: `"Echo from SwiftSynapse: \(goal)"`.
5. Append an `.assistantMessage` transcript entry with the echoed string.
6. Set status to `.completed`.

---

## Tools

_None. This agent does not use LLM tools._

---

## Output

| Field | Type | Description |
|-------|------|-------------|
| transcript | [TranscriptEntry] | Updated with user + assistant entries |

---

## Constraints

- Must not make any LLM calls
- Must not persist user data beyond the session
- Must handle empty input by throwing an error

---

## Success Criteria

- [x] Transcript has exactly 2 entries after a successful run
- [x] First entry is `.userMessage` with content matching the goal
- [x] Second entry is `.assistantMessage` with content matching `"Echo from SwiftSynapse: \(goal)"`
- [x] Status is `.completed` after success, `.error(SimpleEchoError.emptyGoal)` after empty input
- [x] Completes without throwing for any non-empty input

---

## Notes

- Platforms: iOS 26+, macOS 26+, visionOS 2+. Swift 6.2+ strict concurrency.
- Uses `@SpecDrivenAgent` macro; `execute(goal:)` is the agent-specific method alongside the macro-generated `run(goal:)`
