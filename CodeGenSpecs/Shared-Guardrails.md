# Shared Spec: Guardrails

> Safety trait — content safety evaluation for tool arguments, LLM output, and user input.

---

## Summary

Guardrails evaluate content for safety before it flows through the agent pipeline. The system supports input filtering (user prompts), output filtering (LLM responses), and tool argument validation.

---

## Core Types

### GuardrailInput

```swift
public enum GuardrailInput: Sendable {
    case toolArguments(toolName: String, arguments: String)
    case llmOutput(text: String)
    case userInput(text: String)
}
```

### GuardrailDecision

```swift
public enum GuardrailDecision: Sendable {
    case allow
    case sanitize(replacement: String)   // replace content and continue
    case block(reason: String)           // halt with reason
    case warn(reason: String)            // log warning but continue
}
```

### RiskLevel

```swift
public enum RiskLevel: Sendable, Comparable {
    case low, medium, high, critical
}
```

### GuardrailPolicy Protocol

```swift
public protocol GuardrailPolicy: Sendable {
    func evaluate(_ input: GuardrailInput) async -> GuardrailDecision
}
```

### ContentFilter

```swift
public struct ContentFilter: GuardrailPolicy {
    public static let `default`: ContentFilter  // pre-configured with common patterns
}
```

The default `ContentFilter` includes regex patterns for:
- Credit card numbers
- Social Security numbers
- API keys and secrets
- Other PII patterns

### GuardrailPipeline

```swift
public actor GuardrailPipeline {
    public func add(_ policy: any GuardrailPolicy)
    public func evaluate(_ input: GuardrailInput) async -> GuardrailDecision
}
```

Policies are evaluated in order. The most restrictive decision wins: `.block` > `.sanitize` > `.warn` > `.allow`.

### GuardrailError

```swift
public enum GuardrailError: Error, Sendable {
    case blocked(reason: String)
}
```

---

## Usage Pattern

```swift
let pipeline = GuardrailPipeline()
await pipeline.add(ContentFilter.default)
await pipeline.add(MyCustomCompliancePolicy())

// Before sending tool output to LLM:
let decision = await pipeline.evaluate(.toolArguments(toolName: "query", arguments: argsJSON))
switch decision {
case .allow: break
case .sanitize(let safe): // use sanitized content
case .block(let reason): throw GuardrailError.blocked(reason: reason)
case .warn(let reason): // log and continue
}
```

---

## Integration Points

- **AgentToolLoop**: evaluates guardrails on tool arguments before dispatch
- **Hooks**: fires `guardrailTriggered` event when any policy returns non-`.allow`
- **Telemetry**: guardrail activations emit `.guardrailTriggered` telemetry events
- If the Safety trait is disabled, guardrail evaluations compile to no-op stubs (always `.allow`).
