// Generated strictly from Agents/RetryingLLMChatAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseMacrosClient

public enum RetryingLLMChatAgentError: Error, Sendable {
    case noResponseContent
}

@SpecDrivenAgent
public actor RetryingLLMChatAgent {
    private let config: AgentConfiguration

    public init(configuration: AgentConfiguration) throws {
        self.config = configuration
        // Validate that a client can be built (fail-fast on bad config)
        _ = try configuration.buildLLMClient()
    }

    /// Legacy convenience init for backward compatibility.
    public init(serverURL: String, modelName: String, apiKey: String? = nil, maxRetries: Int = 3) throws {
        let config = try AgentConfiguration(serverURL: serverURL, modelName: modelName, apiKey: apiKey, maxRetries: maxRetries)
        try self.init(configuration: config)
    }

    public func execute(goal: String) async throws -> String {
        let client = try config.buildLLMClient()
        let agent = Agent(client: client, model: config.modelName)

        let result = try await retryWithBackoff(maxAttempts: config.maxRetries) {
            await agent.reset()
            return try await agent.send(goal)
        }

        guard !result.isEmpty else {
            throw RetryingLLMChatAgentError.noResponseContent
        }

        _transcript.sync(from: await agent.transcript)
        return result
    }
}
