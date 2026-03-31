# SkillsEnabledAgent Spec

## Purpose

Showcase agent demonstrating the full SwiftSynapse harness with agentskills.io skill integration. Proves that a new agent can be built in ~30 lines of domain logic by leveraging shared types.

## Behavior

1. Accepts a natural-language goal from the user.
2. Discovers agentskills.io-compatible skills from standard filesystem locations (`./skills/`, `~/.config/agent-skills/`, etc.).
3. Builds a `SkillsAgent` with the discovered skill catalog injected into the system prompt and the `activate_skill` tool registered automatically.
4. Sends the goal to the LLM, which can activate discovered skills as needed.
5. Returns the final text response.

## Configuration

Uses `AgentConfiguration` — no manual URL validation. Supports environment-variable-based configuration via `SWIFTSYNAPSE_*` vars.

## Skills Discovery

Skills are loaded from the agentskills.io standard filesystem locations:
- `{cwd}/skills/`
- `{cwd}/.skills/`
- `~/.config/agent-skills/`
- `~/agent-skills/`
- `/usr/local/share/agent-skills/` (macOS/Linux)

Each skill directory contains a `skill.md` with YAML frontmatter and Markdown instructions per the agentskills.io spec.

## Error Handling

- Empty goal → `SkillsEnabledAgentError.emptyGoal`
- Empty LLM response → `SkillsEnabledAgentError.noResponseContent`
- Configuration errors → `AgentConfigurationError` (from shared harness)
- Network/LLM errors propagate directly

## Dependencies

- `AgentConfiguration` (shared harness)
- `SkillStore` / `SkillsAgent` / `Skills` (from SwiftOpenSkills via SwiftSynapseMacrosClient)
- `LLMClient` (from SwiftOpenResponsesDSL via SwiftSynapseMacrosClient)
