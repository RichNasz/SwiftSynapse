// Generated strictly from Agents/LLMChatPersonas/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseHarness

public enum LLMChatPersonasError: Error, Sendable {
    case emptyGoal
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

    /// Entry point with persona support. Sets the persona before delegating to the macro-generated `run(goal:)`.
    public func runWithPersona(goal: String, persona: String?) async throws -> String {
        _pendingPersona = persona
        return try await run(goal: goal)
    }

    public func execute(goal: String) async throws -> String {
        guard !goal.isEmpty else {
            _status = .error(LLMChatPersonasError.emptyGoal)
            throw LLMChatPersonasError.emptyGoal
        }
        let persona = _pendingPersona
        _pendingPersona = nil
        _status = .running
        _transcript.reset()

        let client = try config.buildLLMClient()
        let agent = Agent(client: client, model: config.modelName)

        // First call: get initial response with retry
        let initialResponse = try await retryWithBackoff(maxAttempts: config.maxRetries) {
            await agent.reset()
            return try await agent.send(goal)
        }

        guard !initialResponse.isEmpty else {
            _status = .error(LLMChatPersonasError.noResponseContent)
            throw LLMChatPersonasError.noResponseContent
        }

        lastInitialResponse = initialResponse

        guard let persona else {
            _transcript.sync(from: await agent.transcript)
            _status = .completed(initialResponse)
            return initialResponse
        }

        // Second call: persona rewrite (chains via Agent's lastResponseId)
        let personaPrompt = "Rewrite your previous response in the style and voice of \(persona). Preserve all factual content but express it exactly as \(persona) would speak."
        let personaResponse = try await agent.send(personaPrompt)

        guard !personaResponse.isEmpty else {
            _transcript.sync(from: await agent.transcript)
            _status = .error(LLMChatPersonasError.noPersonaResponseContent)
            throw LLMChatPersonasError.noPersonaResponseContent
        }

        _transcript.sync(from: await agent.transcript)
        _status = .completed(personaResponse)
        return personaResponse
    }
}
