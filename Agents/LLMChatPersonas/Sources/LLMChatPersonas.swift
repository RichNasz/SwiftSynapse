// Generated strictly from Agents/LLMChatPersonas/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseMacrosClient

public enum LLMChatPersonasError: Error, Sendable {
    case emptyGoal
    case invalidServerURL
    case noResponseContent
    case noPersonaResponseContent
}

@SpecDrivenAgent
public actor LLMChatPersonas {
    private let modelName: String
    private let _llmClient: LLMClient
    public private(set) var lastInitialResponse: String?

    public init(serverURL: String, modelName: String, apiKey: String? = nil) throws {
        guard !serverURL.isEmpty,
              let parsedURL = URL(string: serverURL),
              parsedURL.scheme == "http" || parsedURL.scheme == "https" else {
            throw LLMChatPersonasError.invalidServerURL
        }
        self.modelName = modelName
        self._llmClient = try LLMClient(baseURL: serverURL, apiKey: apiKey ?? "")
    }

    public func execute(goal: String, persona: String? = nil) async throws -> String {
        guard !goal.isEmpty else {
            _status = .error(LLMChatPersonasError.emptyGoal)
            throw LLMChatPersonasError.emptyGoal
        }
        _status = .running
        _transcript.append(.userMessage(goal))

        let firstRequest = try ResponseRequest(model: modelName) {
            try RequestTimeout(300)
            try ResourceTimeout(300)
        } input: {
            User(goal)
        }

        let firstResponse = try await _llmClient.send(firstRequest)
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

        let secondRequest = try ResponseRequest(model: modelName) {
            try RequestTimeout(300)
            try ResourceTimeout(300)
            try PreviousResponseId(firstResponseId)
        } input: {
            User(personaPrompt)
        }

        let secondResponse = try await _llmClient.send(secondRequest)
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
