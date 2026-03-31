// Generated strictly from Agents/StreamingChatAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseMacrosClient

public enum StreamingChatAgentError: Error, Sendable {
    case emptyGoal
    case noResponseContent
}

@SpecDrivenAgent
public actor StreamingChatAgent {
    private let config: AgentConfiguration
    private let _llmClient: LLMClient

    public init(configuration: AgentConfiguration) throws {
        self.config = configuration
        self._llmClient = try configuration.buildLLMClient()
    }

    /// Legacy convenience init for backward compatibility.
    public init(serverURL: String, modelName: String, apiKey: String? = nil) throws {
        let config = try AgentConfiguration(serverURL: serverURL, modelName: modelName, apiKey: apiKey)
        try self.init(configuration: config)
    }

    public func execute(goal: String) async throws -> String {
        guard !goal.isEmpty else {
            _status = .error(StreamingChatAgentError.emptyGoal)
            throw StreamingChatAgentError.emptyGoal
        }

        _status = .running
        _transcript.reset()
        _transcript.append(.userMessage(goal))

        let timeout = TimeInterval(config.timeoutSeconds)
        let request = try ResponseRequest(model: config.modelName, stream: true) {
            try RequestTimeout(timeout)
            try ResourceTimeout(timeout)
        } input: {
            User(goal)
        }

        try Task.checkCancellation()

        let stream = _llmClient.stream(request)
        _transcript.setStreaming(true)
        var accumulated = ""

        do {
            for try await event in stream {
                if case .contentPartDelta(let delta, _, _) = event {
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
