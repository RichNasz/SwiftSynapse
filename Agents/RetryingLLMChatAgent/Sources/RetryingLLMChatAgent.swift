// Generated strictly from Agents/RetryingLLMChatAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseMacrosClient

public enum RetryingLLMChatAgentError: Error, Sendable {
    case emptyGoal
    case noResponseContent
}

@SpecDrivenAgent
public actor RetryingLLMChatAgent {
    private let config: AgentConfiguration
    private let _llmClient: LLMClient

    public init(configuration: AgentConfiguration) throws {
        self.config = configuration
        self._llmClient = try configuration.buildLLMClient()
    }

    /// Legacy convenience init for backward compatibility.
    public init(serverURL: String, modelName: String, apiKey: String? = nil, maxRetries: Int = 3) throws {
        let config = try AgentConfiguration(serverURL: serverURL, modelName: modelName, apiKey: apiKey, maxRetries: maxRetries)
        try self.init(configuration: config)
    }

    public func execute(goal: String) async throws -> String {
        guard !goal.isEmpty else {
            _status = .error(RetryingLLMChatAgentError.emptyGoal)
            throw RetryingLLMChatAgentError.emptyGoal
        }

        _status = .running
        _transcript.reset()
        _transcript.append(.userMessage(goal))

        let timeout = TimeInterval(config.timeoutSeconds)
        let request = try ResponseRequest(model: config.modelName) {
            try RequestTimeout(timeout)
            try ResourceTimeout(timeout)
        } input: {
            User(goal)
        }

        try Task.checkCancellation()

        let response: ResponseObject
        do {
            let capturedClient = _llmClient
            response = try await retryWithBackoff(maxAttempts: config.maxRetries) {
                try await capturedClient.send(request)
            }
        } catch {
            _status = .error(error)
            throw error
        }

        let responseText = response.firstOutputText ?? ""

        guard !responseText.isEmpty else {
            _status = .error(RetryingLLMChatAgentError.noResponseContent)
            throw RetryingLLMChatAgentError.noResponseContent
        }

        _transcript.append(.assistantMessage(responseText))
        _status = .completed(responseText)
        return responseText
    }
}
