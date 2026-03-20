// Generated strictly from Agents/LLMChat/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseMacrosClient

public enum LLMChatError: Error, Sendable {
    case emptyGoal
    case invalidServerURL
    case noResponseContent
}

@SpecDrivenAgent
public actor LLMChat {
    private let modelName: String
    private let _llmClient: LLMClient

    public init(serverURL: String, modelName: String, apiKey: String? = nil) throws {
        guard !serverURL.isEmpty,
              let parsedURL = URL(string: serverURL),
              parsedURL.scheme == "http" || parsedURL.scheme == "https" else {
            throw LLMChatError.invalidServerURL
        }
        self.modelName = modelName
        self._llmClient = try LLMClient(baseURL: serverURL, apiKey: apiKey ?? "")
    }

    public func run(goal: String) async throws -> String {
        guard !goal.isEmpty else {
            _status = .failed
            throw LLMChatError.emptyGoal
        }
        _status = .running
        _transcript.append(.userMessage(goal))

        let request = try ResponseRequest(model: modelName) {
            try RequestTimeout(300)
            try ResourceTimeout(300)
        } input: {
            User(goal)
        }

        let response = try await _llmClient.send(request)
        let responseText = response.firstOutputText ?? ""

        guard !responseText.isEmpty else {
            _status = .failed
            throw LLMChatError.noResponseContent
        }

        _transcript.append(.assistantMessage(responseText))
        _status = .completed
        return responseText
    }
}
