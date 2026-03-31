// Generated strictly from Agents/RetryingLLMChatAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseMacrosClient

public enum RetryingLLMChatAgentError: Error, Sendable {
    case emptyGoal
    case invalidServerURL
    case invalidConfiguration
    case noResponseContent
}

@SpecDrivenAgent
public actor RetryingLLMChatAgent {
    private let modelName: String
    private let maxRetries: Int
    private let _llmClient: LLMClient

    public init(serverURL: String, modelName: String, apiKey: String? = nil, maxRetries: Int = 3) throws {
        guard !serverURL.isEmpty,
              let parsedURL = URL(string: serverURL),
              parsedURL.scheme == "http" || parsedURL.scheme == "https" else {
            throw RetryingLLMChatAgentError.invalidServerURL
        }
        guard (1...10).contains(maxRetries) else {
            throw RetryingLLMChatAgentError.invalidConfiguration
        }
        self.modelName = modelName
        self.maxRetries = maxRetries
        self._llmClient = try LLMClient(baseURL: serverURL, apiKey: apiKey ?? "")
    }

    public func execute(goal: String) async throws -> String {
        guard !goal.isEmpty else {
            _status = .error(RetryingLLMChatAgentError.emptyGoal)
            throw RetryingLLMChatAgentError.emptyGoal
        }

        _status = .running
        _transcript.reset()
        _transcript.append(.userMessage(goal))

        let request = try ResponseRequest(model: modelName) {
            try RequestTimeout(300)
            try ResourceTimeout(300)
        } input: {
            User(goal)
        }

        try Task.checkCancellation()

        let response: ResponseObject
        do {
            response = try await retryWithBackoff(maxAttempts: maxRetries) {
                try await self._llmClient.send(request)
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

    private func retryWithBackoff<T: Sendable>(
        maxAttempts: Int,
        baseDelay: Duration = .milliseconds(500),
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                guard isRetryable(error), attempt < maxAttempts else {
                    if attempt >= maxAttempts {
                        break
                    }
                    throw error
                }
                let nextAttempt = attempt + 1
                _transcript.append(.reasoning(
                    ReasoningItem(
                        id: "retry-\(nextAttempt)",
                        summary: [ReasoningSummary(type: "summary_text", text: "Retrying LLM call (attempt \(nextAttempt) of \(maxAttempts))\u{2026}")]
                    )
                ))
                let delayNs = UInt64(baseDelay.components.attoseconds / 1_000_000_000) * UInt64(1 << (attempt - 1))
                try await Task.sleep(nanoseconds: delayNs)
            }
        }
        throw lastError!
    }

    private func isRetryable(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }
        return false
    }
}
