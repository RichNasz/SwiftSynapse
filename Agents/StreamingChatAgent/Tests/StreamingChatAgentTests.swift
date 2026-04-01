// Generated strictly from Agents/StreamingChatAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import Testing
import SwiftSynapseMacrosClient
@testable import StreamingChatAgentAgent

@Test func streamingChatAgentInitThrowsOnInvalidURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try StreamingChatAgent(serverURL: ":::not-a-url", modelName: "test-model")
    }
}

@Test func streamingChatAgentInitThrowsOnEmptyURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try StreamingChatAgent(serverURL: "", modelName: "test-model")
    }
}

@Test func streamingChatAgentThrowsOnEmptyGoal() async throws {
    let agent = try StreamingChatAgent(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    await #expect(throws: AgentLifecycleError.self) {
        try await agent.run(goal: "")
    }
    let status = await agent.status
    guard case .error = status else {
        Issue.record("Expected .error status, got \(status)")
        return
    }
}

@Test func streamingChatAgentInitialStateIsIdle() async throws {
    let agent = try StreamingChatAgent(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    let status = await agent.status
    guard case .idle = status else {
        Issue.record("Expected .idle status, got \(status)")
        return
    }
    let entries = await agent.transcript.entries
    #expect(entries.isEmpty)
    let isStreaming = await agent.transcript.isStreaming
    #expect(!isStreaming)
    let streamingText = await agent.transcript.streamingText
    #expect(streamingText.isEmpty)
}

// MARK: - Live Integration Tests

@Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTSYNAPSE_LIVE_TESTS"] != nil))
func streamingChatAgentLiveResponse() async throws {
    let agent = try StreamingChatAgent(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "nvidia/nemotron-3-nano"
    )
    let result = try await agent.run(goal: "Reply with the single word OK.")
    #expect(!result.isEmpty)

    let status = await agent.status
    guard case .completed = status else {
        Issue.record("Expected .completed status, got \(status)")
        return
    }

    let entries = await agent.transcript.entries
    #expect(entries.count == 2)

    let isStreaming = await agent.transcript.isStreaming
    #expect(!isStreaming)

    let streamingText = await agent.transcript.streamingText
    #expect(streamingText.isEmpty)
}

@Test func streamingChatAgentErrorPathClearsStreaming() async throws {
    // Port 19999 should be unreachable — verifies streaming state is cleaned up on error
    let agent = try StreamingChatAgent(
        serverURL: "http://127.0.0.1:19999/v1/responses",
        modelName: "test-model"
    )
    do {
        _ = try await agent.run(goal: "Hello")
        Issue.record("Expected an error to be thrown")
    } catch {
        // Error expected
    }

    let status = await agent.status
    guard case .error = status else {
        Issue.record("Expected .error status, got \(status)")
        return
    }

    let isStreaming = await agent.transcript.isStreaming
    #expect(!isStreaming, "isStreaming must be false after connection failure")

    let streamingText = await agent.transcript.streamingText
    #expect(streamingText.isEmpty, "streamingText must be empty after connection failure")
}
