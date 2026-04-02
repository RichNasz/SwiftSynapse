# Code Generation Spec: Per-Agent README.md

## Purpose

Generate a `README.md` for each agent in `Agents/<AgentName>/`. The README is derived entirely from the agent's `SPEC.md` and provides a consistent, scannable reference for anyone exploring or using the agent.

## Target Audience

- Developers evaluating which agent to use
- Contributors extending or debugging an agent
- AI code generators that need structured context about an agent

## Tone & Style

- Professional, concise, and technical
- Use headings, tables, code blocks, and bullet lists for scannability
- Match the voice established in the root README (first-person plural "we" for project, third-person for agent)
- No emojis unless the agent's SPEC.md explicitly uses them

## Required Sections (in exact order)

### 1. Header

- Generated-file comment: `<!-- Generated from CodeGenSpecs/Agent-README-Generation.md + Agents/<AgentName>/SPEC.md — Do not edit manually. -->`
- Title: `# <AgentName>`
- One-line description derived from the SPEC Goal section

### 2. Overview

- Expand the SPEC Goal into 2–4 sentences
- List which shared patterns the agent uses (observability, background execution, tools, etc.) or state "none beyond defaults"
- State supported platforms from SPEC Notes or default to project-wide platforms

### 3. Quick Start

- **CLI usage**: show the shell command to run the agent via its executable target
  ```bash
  swift run <executable-name> <arguments>
  ```
- **Programmatic usage**: short Swift snippet showing import, instantiation, and `run()` call
- **SwiftUI usage**: short snippet showing agent in a view with observation
  ```swift
  struct MyView: View {
      @State private var agent = <AgentName>()

      var body: some View {
          // agent.status and agent.transcript update automatically
      }
  }
  ```

### 4. Input

- Reproduce the Input table from SPEC.md verbatim:
  | Field | Type | Description |

### 5. Output

- Reproduce the Output table from SPEC.md verbatim:
  | Field | Type | Description |

### 6. Tools

- Reproduce the Tools table from SPEC.md:
  | Tool Name | Input | Output | Side Effects |
- If the SPEC states "None", omit this section entirely

### 7. How It Works

- Numbered list expanding each task step from SPEC Tasks
- Add brief clarifying context where helpful, but do not invent behavior not in the SPEC

### 8. Transcript Example

- Show a representative transcript output as a fenced code block
- Derive content from SPEC Tasks and Output (e.g., user entry → assistant entry)
- Use realistic but simple example values

### 9. Testing

- Command to run tests:
  ```bash
  swift test --filter <AgentName>Tests
  ```
- Bullet list of what the tests validate, derived from SPEC Success Criteria

### 10. Constraints

- Bullet list reproduced from SPEC Constraints

### 11. File Structure

- Tree view of the agent's directory:
  ```
  Agents/<AgentName>/
  ├── README.md
  ├── specs/
  │   ├── SPEC.md
  │   └── Overview.md
  ├── Sources/
  │   └── <AgentName>.swift
  ├── CLI/
  │   └── <AgentName>CLI.swift
  └── Tests/
      └── <AgentName>Tests.swift
  ```
- Adjust to match actual files present (e.g., omit tools file if agent has no tools)

### 12. License

- Single line: "MIT License — see the root [LICENSE](../../LICENSE) for details."

### 13. Related

- Links to:
  - `specs/SPEC.md` — agent specification
  - `specs/Overview.md` — generation rules
  - Root `README.md` — project overview

## Constraints

- Every piece of content must trace back to the agent's SPEC.md — do not invent features or behaviors
- Include the generated-file header comment at the very top
- Use GitHub-flavored Markdown
- Keep total length under 200 lines for simple agents; scale proportionally for complex ones

## Output Instructions

- Generate the complete `Agents/<AgentName>/README.md` content
- Do not include YAML front-matter
- Use the agent's SPEC.md as the sole source of truth

Generate the agent README.md now.
