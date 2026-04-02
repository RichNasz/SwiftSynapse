<!-- Generated from CodeGenSpecs/Agent-README-Generation.md + Agents/SkillsEnabledAgent/specs/SPEC.md — Do not edit manually. -->

# SkillsEnabledAgent

Discover and activate agentskills.io-compatible skills from standard filesystem locations, then use them to fulfill a natural-language goal.

## Overview

SkillsEnabledAgent demonstrates the full SwiftSynapse harness with agentskills.io skill integration. It discovers skills from standard filesystem locations, injects them into the system prompt, and registers the `activate_skill` tool automatically. The agent proves that a new agent can be built in approximately 30 lines of domain logic by leveraging shared types from the harness.

**Platforms:** iOS 26+, macOS 26+, visionOS 2.4+

## Quick Start

**CLI:**

```bash
swift run skills-enabled-agent "Summarize the latest project notes" \
    --server-url http://127.0.0.1:1234/v1/responses \
    --model llama3
```

**Programmatic:**

```swift
import SkillsEnabledAgentAgent

let agent = try SkillsEnabledAgent(
    serverURL: "http://127.0.0.1:1234/v1/responses",
    modelName: "llama3"
)
let answer = try await agent.execute(goal: "Summarize the latest project notes")
print(answer)
```

**SwiftUI:**

```swift
struct MyView: View {
    @State private var agent = SkillsEnabledAgent()

    var body: some View {
        // agent.status and agent.transcript update automatically
    }
}
```

## Input

| Field | Type | Description |
|-------|------|-------------|
| `goal` | `String` | Natural-language goal for the agent to fulfill |

## Output

| Field | Type | Description |
|-------|------|-------------|
| result | `String` | Final text response from the LLM |

## How It Works

1. Accepts a natural-language goal from the user.
2. Discovers agentskills.io-compatible skills from standard filesystem locations (`./skills/`, `~/.config/agent-skills/`, etc.).
3. Builds a `SkillsAgent` with the discovered skill catalog injected into the system prompt and the `activate_skill` tool registered automatically.
4. Sends the goal to the LLM, which can activate discovered skills as needed.
5. Returns the final text response.

## Skills Discovery

Skills are loaded from the agentskills.io standard filesystem locations:

- `{cwd}/skills/`
- `{cwd}/.skills/`
- `~/.config/agent-skills/`
- `~/agent-skills/`
- `/usr/local/share/agent-skills/` (macOS/Linux)

Each skill directory contains a `skill.md` with YAML frontmatter and Markdown instructions per the agentskills.io spec.

## Transcript Example

```
[user]       Summarize the latest project notes
[toolCall]   activate_skill({"skill": "note-reader"})
[toolResult] activate_skill → "Skill 'note-reader' activated successfully" (0.2s)
[assistant]  Here is a summary of your latest project notes...
```

## Testing

```bash
swift test --filter SkillsEnabledAgentTests
```

- Empty goal throws `SkillsEnabledAgentError.emptyGoal`
- Empty LLM response throws `SkillsEnabledAgentError.noResponseContent`
- Configuration errors produce `AgentConfigurationError`
- Skills are discovered from standard filesystem locations
- Discovered skills appear in the system prompt and tool registry

## Constraints

- Import `SwiftSynapseHarness`; no raw URLSession or OpenAI SDK.
- Uses `AgentConfiguration` for configuration — no manual URL validation.
- Skills discovery follows the agentskills.io standard filesystem convention.
- Network/LLM errors propagate directly.

## File Structure

```
Agents/SkillsEnabledAgent/
├── README.md
├── specs/
│   ├── SPEC.md
│   └── Overview.md
├── Sources/
│   └── SkillsEnabledAgent.swift
├── CLI/
│   └── SkillsEnabledAgentCLI.swift
└── Tests/
    └── SkillsEnabledAgentTests.swift
```

## License

MIT License — see the root [LICENSE](../../LICENSE) for details.

## Related

- [specs/SPEC.md](specs/SPEC.md) — agent specification
- [specs/Overview.md](specs/Overview.md) — generation rules
- [Root README.md](../../README.md) — project overview
