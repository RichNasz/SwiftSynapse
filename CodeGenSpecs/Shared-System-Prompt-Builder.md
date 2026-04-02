# Shared Spec: System Prompt Builder

> Core trait — prioritized, cacheable system prompt composition.

---

## Summary

`SystemPromptBuilder` assembles multi-section system prompts from prioritized components. Sections are added with a priority level and composed into a single prompt string. This avoids ad-hoc string concatenation and ensures consistent prompt structure across agents.

---

## Core Type

```swift
public struct SystemPromptBuilder: Sendable {
    public init()
    public mutating func addSection(_ content: String, priority: Int = 0, label: String? = nil)
    public func build() -> String
}
```

Sections are sorted by priority (highest first) and joined with double newlines. Optional labels add `## Label` headers for readability in debugging.

---

## Usage Pattern

```swift
var builder = SystemPromptBuilder()
builder.addSection("You are a helpful coding assistant.", priority: 100, label: "Role")
builder.addSection("Always respond in Swift.", priority: 50, label: "Constraints")
builder.addSection("Available tools: calculate, convertUnit.", priority: 30, label: "Tools")

let systemPrompt = builder.build()
// Result:
// ## Role
// You are a helpful coding assistant.
//
// ## Constraints
// Always respond in Swift.
//
// ## Tools
// Available tools: calculate, convertUnit.
```

---

## Integration Points

- **Agents**: use `SystemPromptBuilder` to construct system prompts from configuration and tool definitions
- **Skills**: `SkillsAgent` uses the builder to inject skill catalogs into the system prompt
- **Plugins**: plugins can inject sections via the builder during activation
