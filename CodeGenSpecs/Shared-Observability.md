# Shared Spec: Observability

> Defines how every SwiftSynapse agent exposes its internal state and transcript to the rest of the app.

---

## Summary

All agent types are annotated with `@Observable` (Swift Observation framework). SwiftUI views bind directly to agent properties without Combine or `ObservableObject`. State mutations always happen on the `@MainActor` unless explicitly documented otherwise.

Key observable properties every agent must expose: `status` (an agent-specific enum), `transcript` (the shared `AgentTranscript` type), and `isRunning` (a derived `Bool`). Streaming deltas from LLM responses are published as `AsyncStream<TranscriptDelta>` and folded into the transcript in real time.

[Detailed rules to be expanded]
