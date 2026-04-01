// Generated strictly from Agents/StreamingChatAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseMacrosClient

public enum StreamingChatAgentError: Error, Sendable {
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

    /// Legacy convenience init for backward compatibility.
    public init(serverURL: String, modelName: String, apiKey: String? = nil) throws {
        let config = try AgentConfiguration(serverURL: serverURL, modelName: modelName, apiKey: apiKey)
        try self.init(configuration: config)
    }

    public func execute(goal: String) async throws -> String {
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
            throw error
        }

        _transcript.setStreaming(false)

        guard !accumulated.isEmpty else {
            throw StreamingChatAgentError.noResponseContent
        }

        _transcript.append(.assistantMessage(accumulated))
        return accumulated
    }
}
