// Generated strictly from Agents/LLMChat/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import Testing
@testable import LLMChatAgent

@Test func llmChatInitThrowsOnInvalidURL() {
    #expect(throws: LLMChatError.self) {
        _ = try LLMChat(serverURL: ":::not-a-url", modelName: "test-model")
    }
}

@Test func llmChatInitThrowsOnEmptyURL() {
    #expect(throws: LLMChatError.self) {
        _ = try LLMChat(serverURL: "", modelName: "test-model")
    }
}

@Test func llmChatRunThrowsOnEmptyGoal() async throws {
    let agent = try LLMChat(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    await #expect(throws: LLMChatError.self) {
        try await agent.execute(goal: "")
    }
    let status = await agent.status
    guard case .error = status else {
        Issue.record("Expected .error status, got \(status)")
        return
    }
}

@Test func llmChatInitialStateIsIdle() async throws {
    let agent = try LLMChat(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    let status = await agent.status
    guard case .idle = status else {
        Issue.record("Expected .idle status, got \(status)")
        return
    }
    let entries = await agent.transcript.entries
    #expect(entries.isEmpty)
}

// MARK: - Live Integration Tests

@Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTSYNAPSE_LIVE_TESTS"] != nil))
func llmChatLiveResponse() async throws {
    let agent = try LLMChat(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "nvidia/nemotron-3-nano"
    )
    let result = try await agent.execute(goal: "Say hello in exactly 3 words.")
    #expect(!result.isEmpty)

    let status = await agent.status
    guard case .completed = status else {
        Issue.record("Expected .completed status, got \(status)")
        return
    }

    let entries = await agent.transcript.entries
    #expect(entries.count == 2)
}
