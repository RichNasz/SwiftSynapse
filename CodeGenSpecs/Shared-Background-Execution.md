# Shared Spec: Background Execution

> Defines how every SwiftSynapse agent continues processing when the host app is backgrounded.

---

## Summary

Agents that may run longer than a few seconds must register a `BGContinuedProcessingTask` (BackgroundTasks framework, iOS 16+/macOS 13+). The agent's main `Task` is started inside the background task handler and cancelled via `task.expirationHandler` if the system reclaims time. All agent work is expressed as `async` functions so cancellation propagates cleanly through Swift concurrency's cooperative cancellation model.

Agents must checkpoint their progress to allow resumption after expiration. Checkpoint format is agent-specific and described in each agent's own `SPEC.md`. Shared utilities for checkpoint serialization live in `Shared-Transcript.md`.

[Detailed rules to be expanded]
