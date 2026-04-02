# Shared Spec: Cost Tracking

> Observability trait — per-model token pricing, cost records, and cumulative cost tracking.

---

## Summary

Cost tracking extends the telemetry system (see `Shared-Telemetry.md`) with monetary cost calculation for LLM API calls. Agents can monitor spending in real time and enforce budget limits.

---

## Core Types

### ModelPricing

```swift
public struct ModelPricing: Sendable {
    public let inputCostPerMillionTokens: Decimal
    public let outputCostPerMillionTokens: Decimal
    public let cacheCreationCostPerMillionTokens: Decimal?
    public let cacheReadCostPerMillionTokens: Decimal?

    public func cost(inputTokens: Int, outputTokens: Int, cacheCreationTokens: Int = 0, cacheReadTokens: Int = 0) -> Decimal
}
```

### CostRecord

```swift
public struct CostRecord: Sendable {
    public let model: String
    public let inputTokens: Int
    public let outputTokens: Int
    public let cost: Decimal
    public let timestamp: Date
    public let apiDuration: Duration?
}
```

### ModelUsage

```swift
public struct ModelUsage: Sendable {
    public let model: String
    public let totalInputTokens: Int
    public let totalOutputTokens: Int
    public let totalCost: Decimal
    public let callCount: Int
}
```

### CostTracker

```swift
public actor CostTracker {
    public func setPricing(for model: String, pricing: ModelPricing)
    public func record(model: String, inputTokens: Int, outputTokens: Int, duration: Duration?)
    public func totalCost() -> Decimal
    public func totalAPIDuration() -> Duration
    public func usageByModel() -> [ModelUsage]
    public func allRecords() -> [CostRecord]
    public func reset()
}
```

### CostTrackingTelemetrySink

```swift
public struct CostTrackingTelemetrySink: TelemetrySink {
    public init(tracker: CostTracker)
}
```

Listens for `.llmCallMade` telemetry events and automatically records costs. Compose with other sinks via `CompositeTelemetrySink`.

---

## Usage Pattern

```swift
let tracker = CostTracker()
await tracker.setPricing(for: "gpt-4o", pricing: ModelPricing(
    inputCostPerMillionTokens: 2.50,
    outputCostPerMillionTokens: 10.00
))

let costSink = CostTrackingTelemetrySink(tracker: tracker)
let compositeSink = CompositeTelemetrySink([costSink, OSLogTelemetrySink()])
agent.configure(telemetry: compositeSink)

// After agent run:
let total = await tracker.totalCost()   // e.g., 0.003250
```

---

## Integration Points

- **Telemetry**: listens to `.llmCallMade` events for automatic recording
- **Token Usage Tracker**: `TokenUsageTracker` actor tracks raw token counts separately
- If the Observability trait is disabled, cost tracking compiles to no-op.
