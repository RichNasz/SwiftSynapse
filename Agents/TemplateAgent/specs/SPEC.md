# Agent Spec: [AgentName]

> Replace this file with the specification for your agent. This template defines all required sections.

---

## Goal

_What is the single, clear purpose of this agent? One or two sentences._

[PLACEHOLDER — describe what this agent does and why it exists]

---

## Input

_What does the agent receive when it is invoked?_

| Field | Type | Description |
|-------|------|-------------|
| [field] | [Type] | [Description] |

---

## Tasks

_Ordered list of steps the agent performs to achieve its goal._

1. [Step 1]
2. [Step 2]
3. [Step 3]

---

## Tools

_LLM tools this agent exposes. Each tool will be generated from a `@LLMTool` macro._

| Tool Name | Input | Output | Side Effects |
|-----------|-------|--------|--------------|
| [toolName] | [params] | [return type] | [e.g. network, file I/O, none] |

---

## Output

_What does the agent produce when it completes successfully?_

| Field | Type | Description |
|-------|------|-------------|
| [field] | [Type] | [Description] |

---

## Constraints

_Rules the agent must never violate._

- [PLACEHOLDER — e.g. "Must not make more than N LLM calls per invocation"]
- [PLACEHOLDER — e.g. "Must complete within N seconds or checkpoint and defer"]
- [PLACEHOLDER — e.g. "Must not persist user data beyond the session"]

---

## Success Criteria

_How do we know the agent worked correctly?_

- [ ] [PLACEHOLDER — e.g. "Returns a non-empty result for any valid input"]
- [ ] [PLACEHOLDER — e.g. "Transcript contains at least one assistant turn"]
- [ ] [PLACEHOLDER — e.g. "Completes without throwing for the happy path"]

---

## Notes

_Any additional context, edge cases, or open questions._

[PLACEHOLDER]
