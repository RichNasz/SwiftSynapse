// Generated strictly from Agents/LLMChatPersonas/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseMacrosClient

public enum LLMChatPersonasError: Error, Sendable {
    case noResponseContent
    case noPersonaResponseContent
}

@SpecDrivenAgent
public actor LLMChatPersonas {
    private let config: AgentConfiguration
    public private(set) var lastInitialResponse: String?
    private var _pendingPersona: String?

    public init(configuration: AgentConfiguration) throws {
        self.config = configuration
        // Validate that a client can be built (fail-fast on bad config)
        _ = try configuration.buildLLMClient()
    }

    /// Legacy convenience init for backward compatibility.
    public init(serverURL: String, modelName: String, apiKey: String? = nil) throws {
        let config = try AgentConfiguration(serverURL: serverURL, modelName: modelName, apiKey: apiKey)
        try self.init(configuration: config)
    }

    /// Entry point with persona support. Sets the persona before delegating to the macro-generated `run(goal:)`.
    public func runWithPersona(goal: String, persona: String?) async throws -> String {
        _pendingPersona = persona
        return try await run(goal: goal)
    }

    public func execute(goal: String) async throws -> String {
        let persona = _pendingPersona
        _pendingPersona = nil
        let client = try config.buildLLMClient()
        let agent = Agent(client: client, model: config.modelName)

        // First call: get initial response
        let initialResponse = try await retryWithBackoff(maxAttempts: config.maxRetries) {
            await agent.reset()
            return try await agent.send(goal)
        }

        guard !initialResponse.isEmpty else {
            throw LLMChatPersonasError.noResponseContent
        }

        lastInitialResponse = initialResponse

        guard let persona else {
            _transcript.sync(from: await agent.transcript)
            return initialResponse
        }

        // Second call: persona rewrite (chains via Agent's lastResponseId)
        let personaPrompt = "Rewrite your previous response in the style and voice of \(persona). Preserve all factual content but express it exactly as \(persona) would speak."
        let personaResponse = try await agent.send(personaPrompt)

        guard !personaResponse.isEmpty else {
            _transcript.sync(from: await agent.transcript)
            throw LLMChatPersonasError.noPersonaResponseContent
        }

        _transcript.sync(from: await agent.transcript)
        return personaResponse
    }
}
