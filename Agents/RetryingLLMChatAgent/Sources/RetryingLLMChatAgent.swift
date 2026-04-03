// Generated strictly from Agents/RetryingLLMChatAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseHarness

public enum RetryingLLMChatAgentError: Error, Sendable {
    case emptyGoal
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

    public func execute(goal: String) async throws -> String {
        guard !goal.isEmpty else {
            _status = .error(RetryingLLMChatAgentError.emptyGoal)
            throw RetryingLLMChatAgentError.emptyGoal
        }
        _status = .running
        _transcript.reset()

        let client = try config.buildLLMClient()
        let agent = Agent(client: client, model: config.modelName)

        let result: String
        do {
            result = try await retryWithBackoff(maxAttempts: config.maxRetries) {
                await agent.reset()
                return try await agent.send(goal)
            }
        } catch {
            _status = .error(error)
            throw error
        }

        guard !result.isEmpty else {
            _status = .error(RetryingLLMChatAgentError.noResponseContent)
            throw RetryingLLMChatAgentError.noResponseContent
        }

        _transcript.sync(from: await agent.transcript)
        _status = .completed(result)
        return result
    }
}
