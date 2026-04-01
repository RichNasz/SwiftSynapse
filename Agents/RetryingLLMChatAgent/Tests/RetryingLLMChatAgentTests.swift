// Generated strictly from Agents/RetryingLLMChatAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import Testing
import SwiftSynapseHarness
@testable import RetryingLLMChatAgentAgent

@Test func retryingAgentInitThrowsOnInvalidURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try RetryingLLMChatAgent(serverURL: ":::not-a-url", modelName: "test-model")
    }
}

@Test func retryingAgentInitThrowsOnEmptyURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try RetryingLLMChatAgent(serverURL: "", modelName: "test-model")
    }
}

@Test func retryingAgentThrowsOnEmptyGoal() async throws {
    let agent = try RetryingLLMChatAgent(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    await #expect(throws: AgentLifecycleError.self) {
        try await agent.run(goal: "")
    }
    let status = await agent.status
    guard case .error = status else {
        Issue.record("Expected .error status, got \(status)")
        return
    }
}

@Test func retryingAgentInitialStateIsIdle() async throws {
    let agent = try RetryingLLMChatAgent(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    let status = await agent.status
    guard case .idle = status else {
        Issue.record("Expected .idle status, got \(status)")
        return
    }
    let entries = await agent.transcript.entries
    #expect(entries.isEmpty)
}

@Test func retryingAgentMaxRetriesValidation() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try RetryingLLMChatAgent(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model", maxRetries: 0)
    }
    #expect(throws: AgentConfigurationError.self) {
        _ = try RetryingLLMChatAgent(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model", maxRetries: 11)
    }
}

// MARK: - Live Integration Tests

@Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTSYNAPSE_LIVE_TESTS"] != nil))
func retryingAgentLiveResponse() async throws {
    let agent = try RetryingLLMChatAgent(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "nvidia/nemotron-3-nano",
        maxRetries: 3
    )
    let result = try await agent.run(goal: "Reply with the single word OK.")
    #expect(!result.isEmpty)

    let status = await agent.status
    guard case .completed = status else {
        Issue.record("Expected .completed status, got \(status)")
        return
    }

    let entries = await agent.transcript.entries
    // Should have userMessage + assistantMessage (no retries expected on a healthy server)
    #expect(entries.count == 2)
}

@Test func retryingAgentNonRetryableErrorPropagatesImmediately() async throws {
    // Port 19999 should be unreachable — cannotConnectToHost is NOT retryable
    let agent = try RetryingLLMChatAgent(
        serverURL: "http://127.0.0.1:19999/v1/responses",
        modelName: "test-model",
        maxRetries: 3
    )
    do {
        _ = try await agent.run(goal: "Hello")
        Issue.record("Expected an error to be thrown")
    } catch {
        // Error should propagate — that's correct
    }

    let status = await agent.status
    guard case .error = status else {
        Issue.record("Expected .error status, got \(status)")
        return
    }

    let entries = await agent.transcript.entries
    // Should have userMessage only — no .reasoning retry entries since cannotConnectToHost is not retryable
    let reasoningEntries = entries.filter {
        if case .reasoning = $0 { return true }
        return false
    }
    #expect(reasoningEntries.isEmpty, "Non-retryable errors should not produce retry reasoning entries")
}
