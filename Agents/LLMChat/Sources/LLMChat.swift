// Generated strictly from Agents/LLMChat/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseHarness

public enum LLMChatError: Error, Sendable {
    case emptyGoal
    case noResponseContent
}

@SpecDrivenAgent
public actor LLMChat {
    private let config: AgentConfiguration

    public init(configuration: AgentConfiguration) throws {
        self.config = configuration
        // Validate that a client can be built (fail-fast on bad config)
        _ = try configuration.buildLLMClient()
    }

    public func execute(goal: String) async throws -> String {
        guard !goal.isEmpty else {
            _status = .error(LLMChatError.emptyGoal)
            throw LLMChatError.emptyGoal
        }
        _status = .running
        _transcript.reset()

        let client = try config.buildLLMClient()
        let agent = Agent(client: client, model: config.modelName)

        let result = try await retryWithBackoff(maxAttempts: config.maxRetries) {
            await agent.reset()
            return try await agent.send(goal)
        }

        guard !result.isEmpty else {
            _status = .error(LLMChatError.noResponseContent)
            throw LLMChatError.noResponseContent
        }

        _transcript.sync(from: await agent.transcript)
        _status = .completed(result)
        return result
    }
}
