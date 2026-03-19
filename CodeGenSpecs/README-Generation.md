# Spec: README Generation

> This file drives the generation of the top-level `README.md` for the SwiftSynapse repository.

---

## Purpose

The `README.md` is a generated artifact. It must never be edited manually. To update the README, edit this spec and re-run the generator.

---

## Required Sections (in order)

### 1. Hero
- Project name as an `<h1>`
- One-sentence tagline
- Badges: Swift version, platforms, license

### 2. Overview
- 2–4 paragraphs describing what SwiftSynapse is, why it exists, and who it is for
- Reference the spec-driven, AI-first workflow
- Link to `VISION.md`

### 3. Features
- Bulleted list of key capabilities
- Must include: observable agents, background execution, type-safe tool calling, zero extra deps, Foundation Models compatibility, SwiftUI-ready

### 4. Quick Start
- Step-by-step guide to cloning the repo and running the first agent example
- Include code snippets (Swift)
- Note: snippets are generated from agent specs, not written by hand

### 5. Agent Examples
- One subsection per agent in the `Agents/` directory
- Each subsection: agent name, one-sentence purpose, link to its `SPEC.md`, a short generated code snippet

### 6. SDD Workflow (Spec-Driven Development)
- Explain the workflow: write spec → generate code → never edit generated files
- Diagram or ordered list of steps
- Link to `CodeGenSpecs/Overview.md`

### 7. Contributing
- How to add a new agent (copy `TemplateAgent`, write a spec, run generator)
- Code of conduct reference
- PR and issue guidelines

### 8. License
- License name and brief statement
- Link to `LICENSE` file

---

## Generation Rules

- All code snippets must be syntactically valid Swift 6.2
- Badges must use shields.io format
- All internal links must be relative paths
- The file must pass standard Markdown linting (no trailing spaces, consistent heading levels)
