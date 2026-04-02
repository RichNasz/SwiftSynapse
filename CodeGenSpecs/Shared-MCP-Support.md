# Shared Spec: MCP Support

> MCP trait — Model Context Protocol integration for connecting to external data sources.

---

## Summary

MCP (Model Context Protocol) enables agents to connect to external servers that provide tools, resources, and context. The harness supports stdio, SSE, and WebSocket transports for MCP server communication.

---

## Core Types

### MCPTransport Protocol

```swift
public protocol MCPTransport: Sendable {
    func send(_ message: MCPMessage) async throws
    func receive() async throws -> MCPMessage
    func close() async
}
```

### MCPTransportType

```swift
public enum MCPTransportType: Sendable {
    case stdio(command: String, arguments: [String])
    case sse(url: URL)
    case webSocket(url: URL)
}
```

### StdioMCPTransport

```swift
public actor StdioMCPTransport: MCPTransport {
    public init(command: String, arguments: [String])
}
```

Launches a child process and communicates via stdin/stdout using JSON-RPC 2.0.

### MCPMessage

```swift
public struct MCPMessage: Codable, Sendable {
    public static func request(method: String, params: AnyCodable?) -> MCPMessage
    public static func notification(method: String, params: AnyCodable?) -> MCPMessage
}
```

### MCPServerConfig

```swift
public struct MCPServerConfig: Sendable {
    public let name: String
    public let transportType: MCPTransportType
}
```

### MCPToolBridge

```swift
public struct MCPToolBridge: AgentToolProtocol {
    // Wraps an MCP tool definition as a native AgentToolProtocol
}
```

Bridges MCP-discovered tools into the `ToolRegistry` so they can be dispatched alongside native tools.

### MCPManager

```swift
public actor MCPManager {
    public func connect(_ config: MCPServerConfig) async throws
    public func disconnect(_ name: String) async
    public func availableTools() async -> [MCPToolDefinition]
    public func bridgeTools(into registry: ToolRegistry) async
}
```

---

## Usage Pattern

```swift
let manager = MCPManager()
try await manager.connect(MCPServerConfig(
    name: "database",
    transportType: .stdio(command: "npx", arguments: ["-y", "@modelcontextprotocol/server-sqlite", "mydb.db"])
))

// Bridge MCP tools into the agent's tool registry
await manager.bridgeTools(into: toolRegistry)
```

---

## Integration Points

- **Tool Registry**: MCP tools are bridged as `AgentToolProtocol` conforming types
- **Hooks**: MCP tool calls fire the same `preToolUse` / `postToolUse` hooks as native tools
- **Graceful Shutdown**: MCP connections are closed during shutdown
- If the MCP trait is disabled, MCP types compile to stubs that throw on connect.
