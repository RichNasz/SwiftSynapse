# Shared Spec: Foundation Models (On-Device Inference)

> Defines how SwiftSynapse agents use Apple's Foundation Models framework for on-device inference, the `AgentLLMClient` abstraction that unifies on-device and cloud execution, and the hybrid fallback pattern.

---

## Summary

SwiftSynapse agents prioritize on-device inference via the Foundation Models framework (iOS 26+, macOS 26+, visionOS 26+) on Apple Intelligence-compatible hardware. When on-device inference is unavailable (unsupported device, model not downloaded, guardrail violation), agents fall back to a cloud-based Open Responses API endpoint. This dual-path execution is transparent to agent logic — agents program against the `AgentLLMClient` protocol, not concrete client types.

---

## AgentLLMClient Protocol

The shared abstraction that all inference clients conform to:

```swift
public protocol AgentLLMClient: Sendable {
    /// Send a request and return the complete response.
    func send(_ request: AgentRequest) async throws -> AgentResponse

    /// Send a request and stream text chunks as they arrive.
    func stream(_ request: AgentRequest) async throws -> AsyncThrowingStream<String, Error>
}
```

Both `LLMClient` (cloud, Open Responses API) and `FoundationModelsClient` (on-device, Foundation Models framework) conform to this protocol.

---

## AgentRequest and AgentResponse

To unify the two backends, agents build an `AgentRequest` — a backend-agnostic representation of a prompt:

```swift
public struct AgentRequest: Sendable {
    public let model: String
    public let systemPrompt: String?
    public let userPrompt: String
    public let tools: [AgentToolDefinition]
    public let timeoutSeconds: Int
    public let previousResponseId: String?

    // Cloud-only fields (ignored by on-device client)
    public let temperature: Double?
    public let maxTokens: Int?
}
```

`AgentResponse` is the unified return type:

```swift
public struct AgentResponse: Sendable {
    /// The model's text output (nil if the model only produced tool calls).
    public let text: String?

    /// Tool calls requested by the model (empty if none).
    public let toolCalls: [AgentToolCall]

    /// Response ID for conversation threading (nil for on-device).
    public let responseId: String?

    /// Token usage (approximate for on-device; exact for cloud).
    public let inputTokens: Int
    public let outputTokens: Int
}

public struct AgentToolCall: Sendable {
    public let id: String
    public let name: String
    public let arguments: String  // raw JSON
}
```

---

## Request and Response Bridging

### Cloud path (LLMClient)

`LLMClient` conforms to `AgentLLMClient` via an extension that converts:
- `AgentRequest` → `ResponseRequest` (using the existing DSL builder)
- `ResponseObject` → `AgentResponse` (mapping `firstOutputText`, `firstFunctionCalls`, token usage)

```swift
extension LLMClient: AgentLLMClient {
    public func send(_ request: AgentRequest) async throws -> AgentResponse {
        let dslRequest = request.toResponseRequest()
        let response = try await self.send(dslRequest)
        return AgentResponse(from: response)
    }

    public func stream(_ request: AgentRequest) async throws -> AsyncThrowingStream<String, Error> {
        let dslRequest = request.toStreamingResponseRequest()
        return try await self.stream(dslRequest)
    }
}
```

### On-device path (FoundationModelsClient)

`FoundationModelsClient` wraps the Foundation Models framework:

```swift
#if canImport(FoundationModels)
import FoundationModels

public struct FoundationModelsClient: AgentLLMClient {
    public init() {}

    public func send(_ request: AgentRequest) async throws -> AgentResponse {
        let session = LanguageModelSession(
            instructions: request.systemPrompt ?? ""
        )

        // Register tools if any (see Tool Bridging below)
        let options = GenerationOptions()
        if !request.tools.isEmpty {
            options.tools = request.tools.map { $0.toFoundationModelsTool() }
        }

        let response = try await session.respond(
            to: request.userPrompt,
            options: options
        )

        return AgentResponse(
            text: response.content,
            toolCalls: response.toolCalls?.map { AgentToolCall(from: $0) } ?? [],
            responseId: nil,  // no response threading on-device
            inputTokens: response.usage?.inputTokens ?? 0,
            outputTokens: response.usage?.outputTokens ?? 0
        )
    }

    public func stream(_ request: AgentRequest) async throws -> AsyncThrowingStream<String, Error> {
        let session = LanguageModelSession(
            instructions: request.systemPrompt ?? ""
        )

        return AsyncThrowingStream { continuation in
            Task {
                do {
                    for try await partial in session.streamResponse(to: request.userPrompt) {
                        continuation.yield(partial.content)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
#endif
```

**Note:** The Foundation Models API surface shown above is illustrative. The actual API may differ when iOS 26 ships. The adapter must be updated to match the released API. The key contract is that `FoundationModelsClient` conforms to `AgentLLMClient` — the internal implementation is an adapter detail.

---

## Tool Bridging

Tools defined via `@LLMTool` (from `SwiftLLMToolMacros`) generate `FunctionToolParam` schemas (JSON Schema format). The Foundation Models framework uses its own tool representation.

`AgentToolDefinition` bridges between them:

```swift
public struct AgentToolDefinition: Sendable {
    public let name: String
    public let description: String
    public let parametersSchema: String  // JSON Schema string

    /// Convert from @LLMTool-generated definition.
    public init(from toolParam: FunctionToolParam) { ... }

    /// Convert to Foundation Models tool format.
    #if canImport(FoundationModels)
    public func toFoundationModelsTool() -> FoundationModels.Tool { ... }
    #endif

    /// Convert to Open Responses API tool format.
    public func toResponseRequestTool() -> FunctionToolParam { ... }
}
```

Tool dispatch remains identical regardless of backend — the agent's `dispatchTool(name:arguments:)` function receives the same `(name: String, arguments: String)` pair from both backends. The `AgentToolCall` type normalizes tool call responses from both backends into the same format.

**Limitation:** If the Foundation Models framework does not support arbitrary JSON Schema tool definitions (it may use `@Generable` types instead), the tool bridging layer will need to generate `@Generable` conformances at compile time or limit on-device tool support to a subset. This limitation should be documented in each tool-using agent's SPEC.md under Constraints.

---

## HybridLLMClient

The hybrid client implements the VISION.md principle: "on-device first with hybrid cloud fallback."

```swift
public struct HybridLLMClient: AgentLLMClient {
    private let onDevice: (any AgentLLMClient)?  // nil if FoundationModels unavailable
    private let cloud: any AgentLLMClient

    public init(cloudClient: any AgentLLMClient) {
        #if canImport(FoundationModels)
        self.onDevice = FoundationModelsClient()
        #else
        self.onDevice = nil
        #endif
        self.cloud = cloudClient
    }

    public func send(_ request: AgentRequest) async throws -> AgentResponse {
        if let onDevice {
            do {
                return try await onDevice.send(request)
            } catch let error as FoundationModelsError where error.isFallbackEligible {
                // On-device failed with a fallback-eligible error → try cloud
                return try await cloud.send(request)
            }
        }
        // No on-device client available → cloud only
        return try await cloud.send(request)
    }

    public func stream(_ request: AgentRequest) async throws -> AsyncThrowingStream<String, Error> {
        if let onDevice {
            do {
                return try await onDevice.stream(request)
            } catch let error as FoundationModelsError where error.isFallbackEligible {
                return try await cloud.stream(request)
            }
        }
        return try await cloud.stream(request)
    }
}
```

---

## FoundationModelsError and Fallback Eligibility

On-device errors from the Foundation Models framework are wrapped in a `FoundationModelsError` type for classification:

```swift
public enum FoundationModelsError: Error, Sendable {
    /// The on-device model is not available (device not supported, model not downloaded).
    case modelNotAvailable

    /// The request was rejected by the on-device guardrail system.
    case guardrailViolation

    /// The on-device model does not support a requested capability (e.g., specific tool format).
    case unsupportedCapability(String)

    /// The on-device generation timed out.
    case generationTimeout

    /// An unknown error from the Foundation Models framework.
    case frameworkError(Error)

    /// Whether this error should trigger a cloud fallback in hybrid mode.
    public var isFallbackEligible: Bool {
        switch self {
        case .modelNotAvailable: return true
        case .unsupportedCapability: return true
        case .generationTimeout: return true
        case .guardrailViolation: return false  // content issue — cloud will likely also reject
        case .frameworkError: return true
        }
    }
}
```

`guardrailViolation` is **not** fallback-eligible — if the on-device model rejected the content, sending the same content to a cloud endpoint is unlikely to succeed and may violate privacy expectations.

---

## ExecutionMode in AgentConfiguration

`AgentConfiguration` (see `Shared-Configuration.md`) gains an `executionMode` field:

```swift
public enum ExecutionMode: Codable, Sendable {
    /// On-device only. Throws if Foundation Models is unavailable.
    case onDevice

    /// Cloud only. Uses serverURL + apiKey. Ignores Foundation Models even if available.
    case cloud

    /// Try on-device first; fall back to cloud on eligible errors.
    /// Requires serverURL + apiKey as fallback parameters.
    case hybrid
}
```

Default: `.hybrid` (matches VISION.md: "on-device first with hybrid cloud fallback").

When `executionMode` is `.onDevice`:
- `serverURL` and `apiKey` are not required (ignored if provided)
- `modelName` is ignored (Foundation Models uses the system model)
- Validation skips URL checks

When `executionMode` is `.cloud`:
- `serverURL` is required (existing behavior)
- Foundation Models framework is not imported or used

When `executionMode` is `.hybrid`:
- `serverURL` is required (for the fallback path)
- On-device is attempted first; cloud is the fallback

---

## Environment Variable

| Variable | Field |
|----------|-------|
| `SWIFTSYNAPSE_EXECUTION_MODE` | `executionMode` — values: `onDevice`, `cloud`, `hybrid` (default: `hybrid`) |

---

## Agent Init with ExecutionMode

The agent init pattern changes to construct the appropriate client:

```swift
public init(configuration: AgentConfiguration) throws {
    self.modelName = configuration.modelName
    self.maxRetries = configuration.maxRetries

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

The stored property is now `_inferenceClient: any AgentLLMClient` instead of `_llmClient: LLMClient`. The macro-generated `_client` property is separate and remains `LLMClient?` for backwards compatibility.

---

## Relationship to Existing Specs

### Shared-LLM-Client.md

`Shared-LLM-Client.md` continues to define the cloud-only `LLMClient` type and the `ResponseRequest` DSL. This spec adds the `AgentLLMClient` protocol that `LLMClient` conforms to. Agents that adopt `AgentLLMClient` program against the protocol; agents that use the legacy direct-init pattern continue to use `LLMClient` directly.

### Shared-Retry-Strategy.md

The `isTransportRetryable` predicate must be extended to handle on-device errors:

- `FoundationModelsError.generationTimeout` → retryable (transient)
- `FoundationModelsError.modelNotAvailable` → **not retryable** (permanent on this device; fallback instead)
- `FoundationModelsError.guardrailViolation` → **not retryable** (content issue)
- `FoundationModelsError.unsupportedCapability` → **not retryable** (permanent)
- `FoundationModelsError.frameworkError` → retryable (unknown, may be transient)

In hybrid mode, retry happens **before** fallback. If the on-device call fails with a retryable error, it is retried up to `maxRetries` times. If it still fails, fallback to cloud is attempted (if the error is fallback-eligible). The cloud call is then also subject to its own retry logic.

### Shared-Telemetry.md

`TelemetryEvent.llmCallMade` gains an `executionMode` field:

```swift
case llmCallMade(model: String, inputTokens: Int, outputTokens: Int, durationMs: Int, executionMode: ExecutionMode)
```

A new event tracks fallback:

```swift
/// On-device call failed and fell back to cloud.
case hybridFallback(agentType: String, onDeviceError: String, durationMs: Int)
```

### Shared-Configuration.md

`AgentConfiguration` gains the `executionMode` field (see above). Validation rules change:
- When `executionMode == .onDevice`: `serverURL` is not validated (may be nil)
- When `executionMode == .cloud` or `.hybrid`: `serverURL` is required

`AgentConfigurationError` gains a new case:
```swift
case foundationModelsUnavailable  // .onDevice requested but #canImport(FoundationModels) is false
```

### Shared-Observability.md

The macro-generated `_client` member remains `LLMClient?` for backwards compatibility. New agents using `AgentLLMClient` store the inference client in a custom `_inferenceClient: any AgentLLMClient` property (not macro-generated).

---

## Conditional Compilation

All Foundation Models code is guarded by `#if canImport(FoundationModels)`:

```swift
#if canImport(FoundationModels)
import FoundationModels
// ... FoundationModelsClient, tool bridging, etc.
#endif
```

On platforms where Foundation Models is not available (older devices, Linux, etc.), the `FoundationModelsClient` type does not exist. `HybridLLMClient` gracefully degrades to cloud-only when `onDevice` is `nil`.

Agents compiled without Foundation Models support:
- `.onDevice` mode throws `AgentConfigurationError.foundationModelsUnavailable` at init
- `.hybrid` mode silently uses cloud-only (no fallback attempt)
- `.cloud` mode works unchanged

---

## Token Counting Differences

| Aspect | Cloud (LLMClient) | On-Device (FoundationModelsClient) |
|--------|-------------------|-------------------------------------|
| Input tokens | Exact (from API response) | Approximate (if provided by framework; otherwise estimated from prompt length) |
| Output tokens | Exact (from API response) | Approximate (estimated from response length) |
| Cost | Billed per token by provider | Free (on-device) |

Telemetry events always report token counts. On-device estimates use `count / 4` as a rough characters-to-tokens approximation (same heuristic as tool result budgeting in `Shared-Tool-Concurrency.md`).

---

## Conversation Threading

The Open Responses API supports `PreviousResponseId` for multi-turn threading (used by `LLMChatPersonas`). The Foundation Models framework uses `LanguageModelSession` which maintains conversation state implicitly within the session object.

`AgentRequest.previousResponseId` is:
- Used by the cloud path to set `PreviousResponseId` in the `ResponseRequest`
- Ignored by the on-device path (the `LanguageModelSession` manages state internally)

For on-device multi-turn conversations, agents must reuse the same `LanguageModelSession` instance across calls. The `FoundationModelsClient` manages this by maintaining an internal session per logical conversation. When `previousResponseId` is non-nil, the client continues the existing session rather than creating a new one.

---

## Device Availability Check

Agents or host apps can check on-device availability before creating an agent:

```swift
#if canImport(FoundationModels)
import FoundationModels

public var isOnDeviceInferenceAvailable: Bool {
    SystemLanguageModel.isAvailable
}
#else
public var isOnDeviceInferenceAvailable: Bool { false }
#endif
```

This is a convenience — agents do not check availability themselves. The `HybridLLMClient` handles unavailability via fallback. The check is useful for UIs that want to show "on-device available" badges or toggle execution mode in settings.

---

## Constraints and Known Limitations

1. **Tool support**: The Foundation Models framework may use `@Generable` for structured output rather than arbitrary JSON Schema tool definitions. If tool bridging is not feasible for a specific tool, that tool should be marked as cloud-only in the agent's SPEC.md and the on-device path should skip tool registration.

2. **Model selection**: On-device uses the system-provided model (`SystemLanguageModel`). There is no model selection — `modelName` from `AgentConfiguration` is ignored. The cloud path uses `modelName` as before.

3. **Response threading**: On-device threading is session-based, not ID-based. Multi-turn agents must account for this difference in their `execute()` implementation.

4. **Guardrail rejections**: On-device models have Apple's guardrail system. Some prompts that work with cloud models may be rejected on-device. This is by design and is not an error in the agent — the agent should surface `guardrailViolation` as a status error, not silently fall back.

5. **Streaming differences**: On-device streaming may yield different chunk sizes than cloud streaming. Agents must not assume chunk boundaries.
