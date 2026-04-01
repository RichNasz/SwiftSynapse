// Generated strictly from Agents/SkillsEnabledAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import Testing
import SwiftSynapseMacrosClient
@testable import SkillsEnabledAgentAgent

@Test func skillsEnabledAgentInitThrowsOnInvalidURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try SkillsEnabledAgent(configuration: try AgentConfiguration(
            serverURL: ":::not-a-url", modelName: "test-model"
        ))
    }
}

@Test func skillsEnabledAgentInitThrowsOnEmptyURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try SkillsEnabledAgent(configuration: try AgentConfiguration(
            serverURL: "", modelName: "test-model"
        ))
    }
}

@Test func skillsEnabledAgentThrowsOnEmptyGoal() async throws {
    let agent = try SkillsEnabledAgent(configuration: try AgentConfiguration(
        serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model"
    ))
    await #expect(throws: AgentLifecycleError.self) {
        try await agent.run(goal: "")
    }
    let status = await agent.status
    guard case .error = status else {
        Issue.record("Expected .error status, got \(status)")
        return
    }
}

@Test func skillsEnabledAgentInitialStateIsIdle() async throws {
    let agent = try SkillsEnabledAgent(configuration: try AgentConfiguration(
        serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model"
    ))
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
func skillsEnabledAgentLiveResponse() async throws {
    let agent = try SkillsEnabledAgent(configuration: try AgentConfiguration(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "nvidia/nemotron-3-nano"
    ))
    let result = try await agent.run(goal: "Reply with the single word OK.")
    #expect(!result.isEmpty)

    let status = await agent.status
    guard case .completed = status else {
        Issue.record("Expected .completed status, got \(status)")
        return
    }

    let entries = await agent.transcript.entries
    #expect(entries.count >= 2)
}
