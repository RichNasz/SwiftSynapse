// Generated strictly from Agents/LLMChatPersonas/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseMacrosClient

public enum LLMChatPersonasError: Error, Sendable {
    case emptyGoal
    case noResponseContent
    case noPersonaResponseContent
}

@SpecDrivenAgent
public actor LLMChatPersonas {
    private let config: AgentConfiguration
    private let _llmClient: LLMClient
    public private(set) var lastInitialResponse: String?

    public init(configuration: AgentConfiguration) throws {
        self.config = configuration
        self._llmClient = try configuration.buildLLMClient()
    }

    /// Legacy convenience init for backward compatibility.
    public init(serverURL: String, modelName: String, apiKey: String? = nil) throws {
        let config = try AgentConfiguration(serverURL: serverURL, modelName: modelName, apiKey: apiKey)
        try self.init(configuration: config)
    }

    public func execute(goal: String, persona: String? = nil) async throws -> String {
        guard !goal.isEmpty else {
            _status = .error(LLMChatPersonasError.emptyGoal)
            throw LLMChatPersonasError.emptyGoal
        }
        _status = .running
        _transcript.reset()
        _transcript.append(.userMessage(goal))

        let timeout = TimeInterval(config.timeoutSeconds)
        let firstRequest = try ResponseRequest(model: config.modelName) {
            try RequestTimeout(timeout)
            try ResourceTimeout(timeout)
        } input: {
            User(goal)
        }

        let firstResponse: ResponseObject
        do {
            let capturedClient = _llmClient
            firstResponse = try await retryWithBackoff(maxAttempts: config.maxRetries) {
                try await capturedClient.send(firstRequest)
            }
        } catch {
            _status = .error(error)
            throw error
        }

        let firstResponseId = firstResponse.id
        let initialResponse = firstResponse.firstOutputText ?? ""

        guard !initialResponse.isEmpty else {
            _status = .error(LLMChatPersonasError.noResponseContent)
            throw LLMChatPersonasError.noResponseContent
        }

        lastInitialResponse = initialResponse
        _transcript.append(.assistantMessage(initialResponse))

        guard let persona else {
            _status = .completed(initialResponse)
            return initialResponse
        }

        let personaPrompt = "Rewrite your previous response in the style and voice of \(persona). Preserve all factual content but express it exactly as \(persona) would speak."
        _transcript.append(.userMessage(personaPrompt))

        let secondRequest = try ResponseRequest(model: config.modelName) {
            try RequestTimeout(timeout)
            try ResourceTimeout(timeout)
            try PreviousResponseId(firstResponseId)
        } input: {
            User(personaPrompt)
        }

        let secondResponse: ResponseObject
        do {
            let capturedClient = _llmClient
            secondResponse = try await retryWithBackoff(maxAttempts: config.maxRetries) {
                try await capturedClient.send(secondRequest)
            }
        } catch {
            _status = .error(error)
            throw error
        }

        let personaResponse = secondResponse.firstOutputText ?? ""

        guard !personaResponse.isEmpty else {
            _status = .error(LLMChatPersonasError.noPersonaResponseContent)
            throw LLMChatPersonasError.noPersonaResponseContent
        }

        _transcript.append(.assistantMessage(personaResponse))
        _status = .completed(personaResponse)
        return personaResponse
    }
}
