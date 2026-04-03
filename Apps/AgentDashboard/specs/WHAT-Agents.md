# WHAT: Agent Catalog

> Defines the 12 runnable agents that the dashboard must expose — their identifiers, display properties, tier groupings, LLM requirements, and any special calling conventions.

---

## Tier Definitions

| Tier | Meaning |
|------|---------|
| **Foundation** | Demonstrates a fundamental agent pattern. No advanced harness traits required. |
| **Advanced** | Demonstrates Safety, Resilience, Persistence, MultiAgent, or Plugins traits. |

---

## Agent Catalog

| ID (enum case) | Display Name | One-Line Description | SF Symbol | Tier | Requires LLM |
|----------------|-------------|----------------------|-----------|------|--------------|
| `simpleEcho` | Simple Echo | Echoes input back — no LLM needed | `repeat` | Foundation | No |
| `llmChat` | LLM Chat | Single LLM call with retry | `bubble.left.and.bubble.right` | Foundation | Yes |
| `llmChatPersonas` | LLM Chat Personas | Two-step pipeline with optional persona rewrite | `person.wave.2` | Foundation | Yes |
| `retryingLLMChat` | Retrying LLM Chat | LLM chat with exponential-backoff retry and transcript annotations | `arrow.trianglehead.clockwise` | Foundation | Yes |
| `streamingChat` | Streaming Chat | Token-by-token streaming response | `text.word.spacing` | Foundation | Yes |
| `toolUsing` | Tool Using | Math and unit conversion via LLM tool dispatch | `wrench.and.screwdriver` | Foundation | Yes |
| `skillsEnabled` | Skills Enabled | agentskills.io integration with skill discovery | `bolt.shield` | Foundation | Yes |
| `prReviewer` | PR Reviewer | Code review with guardrails, permissions, and human-in-the-loop | `checklist` | Advanced | Yes |
| `performanceOptimizer` | Performance Optimizer | Performance analysis with recovery chains and rate limiting | `gauge.with.dots.needle.67percent` | Advanced | Yes |
| `researchAssistant` | Research Assistant | Long-running research with session persistence and MCP | `magnifyingglass.circle` | Advanced | Yes |
| `taskPlanner` | Task Planner | Multi-agent coordination with cost tracking and telemetry | `list.bullet.clipboard` | Advanced | Yes |
| `dataPipeline` | Data Pipeline | Extensible data processing via plugin architecture | `cylinder.split.1x2` | Advanced | Yes |

---

## Special Calling Conventions

### `simpleEcho`
- Swift type: `SimpleEcho` (module: `SimpleEchoAgent`)
- Init: `SimpleEcho()` — no arguments, no configuration
- Run: `agent.run(goal: goal)` — works without any LLM endpoint configured

### `llmChatPersonas`
- Swift type: `LLMChatPersonas` (module: `LLMChatPersonasAgent`)
- Init: `try LLMChatPersonas(configuration: config)`
- **Run: `agent.runWithPersona(goal: goal, persona: persona)`** where `persona` is `String?`
  - Pass `nil` when the persona field is empty
  - This is the only agent that does NOT use `run(goal:)`
- The dashboard must show a persona input field exclusively for this agent

### All Other LLM Agents
- Init: `try AgentType(configuration: config)` (may throw `AgentConfigurationError`)
- Run: `try await agent.run(goal: goal)`
- Configuration: built from the dashboard's current LLM settings before each run

---

## Module Import Names

| Agent | Swift Module Import |
|-------|-------------------|
| SimpleEcho | `SimpleEchoAgent` |
| LLMChat | `LLMChatAgent` |
| LLMChatPersonas | `LLMChatPersonasAgent` |
| RetryingLLMChatAgent | `RetryingLLMChatAgentAgent` |
| StreamingChatAgent | `StreamingChatAgentAgent` |
| ToolUsingAgent | `ToolUsingAgentAgent` |
| SkillsEnabledAgent | `SkillsEnabledAgentAgent` |
| PRReviewer | `PRReviewerAgent` |
| PerformanceOptimizer | `PerformanceOptimizerAgent` |
| ResearchAssistant | `ResearchAssistantAgent` |
| TaskPlanner | `TaskPlannerAgent` |
| DataPipelineAgent | `DataPipelineAgentAgent` |
