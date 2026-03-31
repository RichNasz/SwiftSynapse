# SkillsEnabledAgent — CodeGen Overview

## Agent Type
Skills-aware LLM agent with agentskills.io integration.

## Generated Files
- `Sources/SkillsEnabledAgent.swift` — Agent actor with skill discovery and SkillsAgent delegation
- `CLI/SkillsEnabledAgentCLI.swift` — CLI with `AgentConfiguration.fromEnvironment` support
- `Tests/SkillsEnabledAgentTests.swift` — Unit tests + live integration tests

## Shared Types Used
- `AgentConfiguration` — centralized configuration (no inline URL validation)
- `SkillStore` — agentskills.io skill discovery from filesystem
- `SkillsAgent` — agent wrapper that registers `activate_skill` tool and injects skill catalog
- `Skills` — builder-pattern component for SkillsAgent init
- `@SpecDrivenAgent` macro — generates `_status`, `_transcript`, `status`, `transcript`, `run(goal:)`

## Architecture
This agent demonstrates the full harness. The `execute(goal:)` method:
1. Loads skills via `SkillStore.load()`
2. Creates a `SkillsAgent` with the loaded skills
3. Delegates goal execution to `SkillsAgent.send()`
4. Records the result in the transcript

The agent itself is ~30 lines of domain logic. All configuration validation, retry, and tool infrastructure is handled by the shared harness.

## CLI
Uses `AgentConfiguration.fromEnvironment(overrides:)` — `--server-url` and `--model` are optional, falling back to `SWIFTSYNAPSE_*` environment variables.
