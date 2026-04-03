// Generated strictly from Agents/StreamingChatAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseHarness

public enum StreamingChatAgentError: Error, Sendable {
    case emptyGoal
    case noResponseContent
}

@SpecDrivenAgent
public actor StreamingChatAgent {
    private let config: AgentConfiguration

    public init(configuration: AgentConfiguration) throws {
        self.config = configuration
        // Validate that a client can be built (fail-fast on bad config)
        _ = try configuration.buildLLMClient()
    }

    public func execute(goal: String) async throws -> String {
        guard !goal.isEmpty else {
            _status = .error(StreamingChatAgentError.emptyGoal)
            throw StreamingChatAgentError.emptyGoal
        }
        _status = .running
        _transcript.reset()
        _transcript.append(.userMessage(goal))

        let client = try config.buildLLMClient()
        let agent = Agent(client: client, model: config.modelName)

        let stream = await agent.stream(goal)
        _transcript.setStreaming(true)
        var accumulated = ""

        do {
            for try await event in stream {
                if case .llm(let llmEvent) = event,
                   case .contentPartDelta(let delta, _, _) = llmEvent {
                    accumulated += delta
                    _transcript.appendDelta(delta)
                }
            }
        } catch {
            _transcript.setStreaming(false)
            _status = .error(error)
            throw error
        }

        _transcript.setStreaming(false)

        guard !accumulated.isEmpty else {
            _status = .error(StreamingChatAgentError.noResponseContent)
            throw StreamingChatAgentError.noResponseContent
        }

        _transcript.append(.assistantMessage(accumulated))
        _status = .completed(accumulated)
        return accumulated
    }
}
