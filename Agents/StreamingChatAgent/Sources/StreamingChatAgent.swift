// Generated strictly from Agents/StreamingChatAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseMacrosClient

public enum StreamingChatAgentError: Error, Sendable {
    case emptyGoal
    case invalidServerURL
    case noResponseContent
}

@SpecDrivenAgent
public actor StreamingChatAgent {
    private let modelName: String
    private let _llmClient: LLMClient

    public init(serverURL: String, modelName: String, apiKey: String? = nil) throws {
        guard !serverURL.isEmpty,
              let parsedURL = URL(string: serverURL),
              parsedURL.scheme == "http" || parsedURL.scheme == "https" else {
            throw StreamingChatAgentError.invalidServerURL
        }
        self.modelName = modelName
        self._llmClient = try LLMClient(baseURL: serverURL, apiKey: apiKey ?? "")
    }

    public func execute(goal: String) async throws -> String {
        guard !goal.isEmpty else {
            _status = .error(StreamingChatAgentError.emptyGoal)
            throw StreamingChatAgentError.emptyGoal
        }

        _status = .running
        _transcript.reset()
        _transcript.append(.userMessage(goal))

        let request = try ResponseRequest(model: modelName, stream: true) {
            try RequestTimeout(300)
            try ResourceTimeout(300)
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
