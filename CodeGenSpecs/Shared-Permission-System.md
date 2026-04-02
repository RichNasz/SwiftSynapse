# Shared Spec: Permission System

> Safety trait — policy-driven tool access control with human-in-the-loop approval.

---

## Summary

The permission system gates tool execution behind configurable policies. Before a tool runs, the `PermissionGate` evaluates all registered policies and either allows, denies, or requests approval from a delegate.

---

## Core Types

### ToolPermission

```swift
public enum ToolPermission: Sendable {
    case allowed
    case requiresApproval(reason: String)
    case denied(reason: String)
}
```

### PermissionPolicy Protocol

```swift
public protocol PermissionPolicy: Sendable {
    func evaluate(toolName: String, arguments: String) async -> ToolPermission
}
```

Policies are evaluated in order. The most restrictive result wins: `.denied` > `.requiresApproval` > `.allowed`.

### ToolListPolicy

```swift
public struct ToolListPolicy: PermissionPolicy {
    public static func allow(_ tools: String...) -> ToolListPolicy
    public static func deny(_ tools: String...) -> ToolListPolicy
    public static func requireApproval(_ tools: String...) -> ToolListPolicy
}
```

Rule-based policy using tool name matching.

### ApprovalDelegate Protocol

```swift
public protocol ApprovalDelegate: Sendable {
    func requestApproval(toolName: String, arguments: String, reason: String) async -> Bool
}
```

Called when any policy returns `.requiresApproval`. The delegate presents the request to the user (e.g., via a SwiftUI dialog) and returns `true` to allow or `false` to deny.

### PermissionGate

```swift
public actor PermissionGate {
    public func addPolicy(_ policy: any PermissionPolicy)
    public func setApprovalDelegate(_ delegate: any ApprovalDelegate)
    public func check(toolName: String, arguments: String) async throws -> Void
}
```

Throws `PermissionError.denied` or `PermissionError.rejected` if the tool is blocked.

### PermissionError

```swift
public enum PermissionError: Error, Sendable {
    case denied(toolName: String, reason: String)
    case noApprovalDelegate(toolName: String)
    case rejected(toolName: String)    // delegate returned false
}
```

---

## Usage Pattern

```swift
let gate = PermissionGate()
await gate.addPolicy(ToolListPolicy.deny("deleteFile", "dropTable"))
await gate.addPolicy(ToolListPolicy.requireApproval("sendEmail"))
await gate.setApprovalDelegate(mySwiftUIApprovalDelegate)

// In tool dispatch:
try await gate.check(toolName: "sendEmail", arguments: argsJSON)
// throws if denied or rejected
```

---

## Integration Points

- **AgentToolLoop**: calls `PermissionGate.check()` before each tool dispatch
- **Hooks**: fires `preToolUse` event (hooks can also block, independently of permissions)
- **Telemetry**: permission denials can emit telemetry events
- If the Safety trait is disabled, permission checks compile to no-op stubs (always allowed).

---

## Additional Safety Types

### PermissionMode

```swift
public enum PermissionMode: Sendable {
    case `default`        // normal policy evaluation
    case autoApprove      // skip approval prompts (testing/automation)
    case alwaysPrompt     // always require approval regardless of policy
    case planOnly         // plan tool calls but never execute
}
```

### DenialTracker & AdaptivePermissionGate

- `DenialTracker` actor — records denial history for analytics
- `AdaptivePermissionGate` actor — adjusts policies based on denial patterns
