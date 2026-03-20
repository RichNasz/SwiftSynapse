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

1. Validate that `goal` is non-empty; throw `SimpleEchoError.emptyGoal` and set status to `.failed` if empty.
2. Set status to `.running`.
3. Append a `.user` transcript entry with the goal text.
4. Produce the echoed string: `"Echo from SwiftSynapse: \(goal)"`.
5. Append an `.assistant` transcript entry with the echoed string.
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
- [x] First entry is `.user` with content matching the goal
- [x] Second entry is `.assistant` with content matching `"Echo from SwiftSynapse: \(goal)"`
- [x] Status is `.completed` after success, `.failed` after empty input
- [x] Completes without throwing for any non-empty input

---

## Notes

- Platforms: iOS 18+, macOS 15+, visionOS 2+
- Uses `@SpecDrivenAgent` macro; `run(goal:)` is a custom overload alongside the macro-generated `run(_:)`
