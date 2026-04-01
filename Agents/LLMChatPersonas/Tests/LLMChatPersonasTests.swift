// Generated strictly from Agents/LLMChatPersonas/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import Testing
import SwiftSynapseHarness
@testable import LLMChatPersonasAgent

@Test func initThrowsOnInvalidURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try LLMChatPersonas(serverURL: ":::not-a-url", modelName: "test-model")
    }
}

@Test func initThrowsOnEmptyURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try LLMChatPersonas(serverURL: "", modelName: "test-model")
    }
}

@Test func runThrowsOnEmptyGoal() async throws {
    let agent = try LLMChatPersonas(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    await #expect(throws: AgentLifecycleError.self) {
        try await agent.run(goal: "")
    }
    let status = await agent.status
    guard case .error = status else {
        Issue.record("Expected .error status, got \(status)")
        return
    }
}

@Test func initialStateIsIdle() async throws {
    let agent = try LLMChatPersonas(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
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
func llmChatPersonasLiveWithoutPersona() async throws {
    let agent = try LLMChatPersonas(
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
    // No persona: userMessage + assistantMessage = 2
    #expect(entries.count == 2)
}

@Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTSYNAPSE_LIVE_TESTS"] != nil))
func llmChatPersonasLiveWithPersona() async throws {
    let agent = try LLMChatPersonas(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "nvidia/nemotron-3-nano"
    )
    let result = try await agent.runWithPersona(goal: "What is 2+2?", persona: "pirate")
    #expect(!result.isEmpty)

    let status = await agent.status
    guard case .completed = status else {
        Issue.record("Expected .completed status, got \(status)")
        return
    }

    let entries = await agent.transcript.entries
    // With persona: userMessage + assistantMessage + userMessage(persona prompt) + assistantMessage = 4
    #expect(entries.count == 4)

    let initialResponse = await agent.lastInitialResponse
    #expect(initialResponse != nil)
    #expect(!initialResponse!.isEmpty)
}
