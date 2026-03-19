# Shared Spec: Transcript

> Defines the canonical transcript model used by all SwiftSynapse agents to record conversation history and streaming output.

---

## Summary

`AgentTranscript` is the single shared type that represents the full conversation between an agent and an LLM, including user turns, assistant turns, tool calls, and tool results. It is `@Observable` and `Sendable`. New entries are appended via a thread-safe async method; the transcript is never mutated directly by callers.

Streaming deltas (`TranscriptDelta`) are the granular units emitted during an LLM response — a token, a tool-call start, a tool-call argument chunk, or a tool-call end. The agent folds each delta into the transcript in real time, so SwiftUI views always reflect the latest partial state without waiting for the full response.

[Detailed rules to be expanded]
