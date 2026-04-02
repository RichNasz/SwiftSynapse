# Shared Spec: Conversation Integrity

> Resilience trait — detect and repair transcript violations.

---

## Summary

Conversation integrity ensures the transcript maintains valid structure: every tool call has a matching tool result, entries follow valid sequencing, and no orphaned entries exist. When violations are detected, the system can automatically repair them.

---

## Core Types

### IntegrityViolation

```swift
public enum IntegrityViolation: Sendable {
    case orphanedToolCall(callId: String)     // tool call with no matching result
    case orphanedToolResult(callId: String)   // tool result with no matching call
    case invalidSequence                       // entries in impossible order
}
```

### TranscriptIntegrityCheck

```swift
public struct TranscriptIntegrityCheck: Sendable {
    public static func validate(_ entries: [TranscriptEntry]) -> [IntegrityViolation]
}
```

Returns an empty array if the transcript is valid.

### ConversationRecoveryStrategy Protocol

```swift
public protocol ConversationRecoveryStrategy: Sendable {
    func recover(from violations: [IntegrityViolation], in entries: inout [TranscriptEntry])
}
```

### DefaultConversationRecoveryStrategy

The default strategy:
- Removes orphaned tool results
- Adds synthetic error results for orphaned tool calls
- Reorders entries to fix invalid sequences

### recoverTranscript

```swift
public func recoverTranscript(
    _ entries: inout [TranscriptEntry],
    strategy: any ConversationRecoveryStrategy = DefaultConversationRecoveryStrategy()
) -> [IntegrityViolation]
```

Validates, repairs, and returns the violations that were fixed.

---

## Integration Points

- **Session Resume**: validates transcript integrity after restoring from `AgentSession`
- **Hooks**: fires `transcriptRepaired` event when violations are fixed
- **Transcript Compressor**: validates after compression to ensure structural integrity
- If the Resilience trait is disabled, integrity checks compile to no-op (no violations reported).
