# Shared Spec: Graceful Shutdown

> Core trait — LIFO handler execution for clean agent termination.

---

## Summary

`GracefulShutdownHandler` manages cleanup operations when an agent is cancelled or the process is terminating. Handlers execute in LIFO (last-in, first-out) order to ensure proper teardown sequencing.

---

## Core Types

```swift
public actor GracefulShutdownHandler {
    public func register(_ handler: @Sendable @escaping () async -> Void)
    public func shutdown() async
}
```

### ShutdownRegistry

```swift
public enum ShutdownRegistry {
    public static func register(_ handler: @Sendable @escaping () async -> Void)
    public static func shutdownAll() async
}
```

Global registry for process-level shutdown handlers. Listens for `SIGTERM` and `SIGINT` signals.

---

## Usage Pattern

```swift
// Register cleanup in agent init or setup
shutdownHandler.register {
    await sessionStore.save(currentSession)
}
shutdownHandler.register {
    await telemetrySink.flush()
}

// On shutdown: telemetry flushes first (LIFO), then session saves
```

---

## Integration Points

- **Session Persistence**: saves current session on shutdown
- **Telemetry**: flushes pending events
- **MCP**: closes MCP server connections
- **Background Execution**: registered as a BGContinuedProcessingTask expiration handler
