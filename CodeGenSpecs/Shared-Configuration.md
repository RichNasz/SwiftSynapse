# Shared Spec: Configuration

> Defines `AgentConfiguration`, the shared value type that replaces duplicated init parameters across LLM-calling agents.

---

## Summary

`AgentConfiguration` is a `Codable`, `Sendable` struct that centralizes all per-agent tuning parameters. Agents accept it at init time instead of individual `serverURL`, `modelName`, `apiKey` parameters. Configuration is resolved in priority order: defaults → environment variables → caller-provided values.

---

## AgentConfiguration Type

```swift
public struct AgentConfiguration: Codable, Sendable {
    public let executionMode: ExecutionMode  // default: .hybrid
    public let serverURL: String?            // required for .cloud and .hybrid; nil allowed for .onDevice
    public let modelName: String             // ignored by on-device; used by cloud
    public let apiKey: String?
    public let timeoutSeconds: Int           // default: 300
    public let maxRetries: Int               // default: 3
    public let toolResultBudgetTokens: Int   // default: 4096

    public init(
        executionMode: ExecutionMode = .hybrid,
        serverURL: String? = nil,
        modelName: String = "",
        apiKey: String? = nil,
        timeoutSeconds: Int = 300,
        maxRetries: Int = 3,
        toolResultBudgetTokens: Int = 4096
    ) throws {
        // Validate based on execution mode
        try AgentConfiguration.validate(
            executionMode: executionMode,
            serverURL: serverURL,
            modelName: modelName,
            timeoutSeconds: timeoutSeconds,
            maxRetries: maxRetries
        )
        self.executionMode = executionMode
        self.serverURL = serverURL
        self.modelName = modelName
        self.apiKey = apiKey
        self.timeoutSeconds = timeoutSeconds
        self.maxRetries = maxRetries
        self.toolResultBudgetTokens = toolResultBudgetTokens
    }
}

public enum ExecutionMode: Codable, Sendable {
    /// On-device only via Foundation Models framework.
    /// Throws if Foundation Models is unavailable on the current device.
    case onDevice

    /// Cloud only via Open Responses API. Requires serverURL.
    case cloud

    /// Try on-device first; fall back to cloud on eligible errors.
    /// Requires serverURL as fallback. Default mode.
    case hybrid
}
```

---

## Validation Rules

Validated in `AgentConfiguration.validate(...)` (a static throwing method). Rules depend on `executionMode`:

| Field | Rule | Error | Modes |
|-------|------|-------|-------|
| `serverURL` | Non-empty; URL must parse; scheme must be `http` or `https` | `AgentConfigurationError.invalidServerURL` | `.cloud`, `.hybrid` only |
| `serverURL` | May be nil (ignored) | — | `.onDevice` only |
| `modelName` | Non-empty | `AgentConfigurationError.emptyModelName` | `.cloud`, `.hybrid` only |
| `modelName` | May be empty (ignored; system model used) | — | `.onDevice` only |
| `timeoutSeconds` | Must be > 0 | `AgentConfigurationError.invalidTimeout` | All modes |
| `maxRetries` | Must be in `1...10` | `AgentConfigurationError.invalidMaxRetries` | All modes |

`toolResultBudgetTokens` is not validated (any positive value is acceptable; 0 disables budgeting).

---

## AgentConfigurationError

```swift
public enum AgentConfigurationError: Error, Sendable {
    case invalidServerURL
    case invalidTimeout
    case invalidMaxRetries
    case emptyModelName
    case foundationModelsUnavailable  // .onDevice requested but platform does not support it
}
```

This is a **shared** error type defined in `SwiftSynapseMacrosClient`. Agents do not define it.

---

## Layered Resolution

`AgentConfiguration.fromEnvironment(overrides:)` is a static factory that merges layers in priority order (later wins):

```
1. Compiled defaults (executionMode: .hybrid, timeoutSeconds: 300, maxRetries: 3, toolResultBudgetTokens: 4096)
2. Environment variables (SWIFTSYNAPSE_EXECUTION_MODE, SWIFTSYNAPSE_SERVER_URL, SWIFTSYNAPSE_MODEL,
                          SWIFTSYNAPSE_API_KEY, SWIFTSYNAPSE_TIMEOUT, SWIFTSYNAPSE_MAX_RETRIES)
3. Caller-provided values (the `overrides` parameter)
```

```swift
// From environment only
let config = try AgentConfiguration.fromEnvironment()

// Env vars as base, caller values override specific fields
let config = try AgentConfiguration.fromEnvironment(overrides: .init(
    serverURL: commandLineURL,
    modelName: commandLineModel
))
```

Environment variable names:

| Variable | Field |
|----------|-------|
| `SWIFTSYNAPSE_EXECUTION_MODE` | `executionMode` — values: `onDevice`, `cloud`, `hybrid` (default: `hybrid`) |
| `SWIFTSYNAPSE_SERVER_URL` | `serverURL` |
| `SWIFTSYNAPSE_MODEL` | `modelName` |
| `SWIFTSYNAPSE_API_KEY` | `apiKey` |
| `SWIFTSYNAPSE_TIMEOUT` | `timeoutSeconds` |
| `SWIFTSYNAPSE_MAX_RETRIES` | `maxRetries` |

If a required field (`serverURL` for cloud/hybrid, `modelName` for cloud/hybrid) is absent from all layers, `fromEnvironment()` throws the corresponding `AgentConfigurationError`. For `.onDevice` mode, `serverURL` and `modelName` are not required.

---

## Agent Init Pattern

Agents that previously took `serverURL`, `modelName`, `apiKey` directly now take `AgentConfiguration`:

```swift
// OLD (deprecated pattern)
public init(serverURL: String, modelName: String, apiKey: String? = nil) throws

// NEW (preferred pattern)
public init(configuration: AgentConfiguration) throws {
    self.modelName = configuration.modelName
    self.maxRetries = configuration.maxRetries

    // Build the appropriate inference client based on execution mode
    switch configuration.executionMode {
    case .onDevice:
        #if canImport(FoundationModels)
        self._inferenceClient = FoundationModelsClient()
        #else
        throw AgentConfigurationError.foundationModelsUnavailable
        #endif
    case .cloud:
        self._inferenceClient = try LLMClient(
            baseURL: configuration.serverURL!,
            apiKey: configuration.apiKey ?? ""
        )
    case .hybrid:
        let cloud = try LLMClient(
            baseURL: configuration.serverURL!,
            apiKey: configuration.apiKey ?? ""
        )
        self._inferenceClient = HybridLLMClient(cloudClient: cloud)
    }
}
```

The stored property is `_inferenceClient: any AgentLLMClient` (see `Shared-Foundation-Models.md`). Agents that use `AgentConfiguration` do **not** repeat URL validation themselves — that is done inside `AgentConfiguration.init()`.

---

## Migration Note: Old vs. New Init Patterns

Existing agents (`LLMChat`, `LLMChatPersonas`) use the legacy direct-parameter init:

```swift
public init(serverURL: String, modelName: String, apiKey: String? = nil) throws
```

New agents (`ToolUsingAgent`, `StreamingChatAgent`, `RetryingLLMChatAgent`) use `AgentConfiguration`:

```swift
public init(configuration: AgentConfiguration) throws
```

Both patterns are valid. Old agents are not required to migrate to `AgentConfiguration` immediately. When an old agent is next regenerated or its spec is updated, it should adopt `AgentConfiguration` at that time. The legacy pattern should not be used for new agents.

---

## Relationship to configure(client:)

The macro-generated `configure(client:)` method is for injecting a pre-built `LLMClient` (useful in tests or when the caller manages the LLM client lifecycle). `AgentConfiguration` is for constructing the `LLMClient` from primitive values (typical for CLI tools and app-level initialization). Both pathways are valid:

```swift
// Pathway 1: AgentConfiguration (recommended for new agents)
let config = try AgentConfiguration(serverURL: url, modelName: model)
let agent = try MyAgent(configuration: config)

// Pathway 2: configure(client:) (macro-generated; useful for testing)
let agent = MyAgent()
await agent.configure(client: mockClient)
```

When an agent is initialized via `AgentConfiguration`, the `_llmClient` stored property is set at init time, not via `configure(client:)`. These are mutually exclusive pathways for any given instance.

---

## CLI Integration

CLI commands use `AgentConfiguration.fromEnvironment(overrides:)` to read env vars and then apply `@Option` flag values as overrides:

```swift
func run() async throws {
    let config = try AgentConfiguration.fromEnvironment(overrides: .init(
        serverURL: serverURL,    // @Option, may be nil if env var is set
        modelName: model,
        apiKey: apiKey
    ))
    let agent = try MyAgent(configuration: config)
    let result = try await agent.execute(goal: goal)
    print(result)
}
```

This means users can set `SWIFTSYNAPSE_SERVER_URL` and `SWIFTSYNAPSE_MODEL` once and omit `--server-url` / `--model` from every CLI invocation.
