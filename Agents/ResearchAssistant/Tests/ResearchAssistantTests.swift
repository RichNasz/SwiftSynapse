// Generated strictly from Agents/ResearchAssistant/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import Testing
import SwiftSynapseHarness
@testable import ResearchAssistantAgent

@Test func researchAssistantInitThrowsOnInvalidURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try AgentConfiguration(serverURL: ":::not-a-url", modelName: "test-model")
    }
}

@Test func researchAssistantThrowsOnEmptyGoal() async throws {
    let config = try AgentConfiguration(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    let agent = try ResearchAssistant(configuration: config)
    await #expect(throws: AgentLifecycleError.self) {
        try await agent.run(goal: "")
    }
    let status = await agent.status
    guard case .error = status else {
        Issue.record("Expected .error status, got \(status)")
        return
    }
}

@Test func researchAssistantInitialStateIsIdle() async throws {
    let config = try AgentConfiguration(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    let agent = try ResearchAssistant(configuration: config)
    let status = await agent.status
    guard case .idle = status else {
        Issue.record("Expected .idle status, got \(status)")
        return
    }
    let entries = await agent.transcript.entries
    #expect(entries.isEmpty)
}

// MARK: - Tool Unit Tests

@Test func searchWebToolReturnsResults() async throws {
    let tool = SearchWeb()
    let result = try await tool.call(arguments: .init(query: "Swift concurrency", maxResults: 3))
    #expect(result.content.contains("Result 1"))
    #expect(result.content.contains("Swift concurrency"))
    let data = Data(result.content.utf8)
    let parsed = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    #expect(parsed?.count == 3)
}

@Test func readDocumentToolReturnsContent() async throws {
    let tool = ReadDocument()
    let result = try await tool.call(arguments: .init(url: "https://example.com/paper.pdf"))
    #expect(result.content.contains("Document content extracted"))
    #expect(result.content.contains("https://example.com/paper.pdf"))
}

@Test func saveMemoryToolReturnsConfirmation() async throws {
    let tool = SaveMemory()
    let result = try await tool.call(arguments: .init(
        content: "Key finding about Swift actors",
        category: "finding",
        tags: ["swift", "concurrency"]
    ))
    #expect(result.content.contains("Memory saved"))
    #expect(result.content.contains("category: finding"))
    #expect(result.content.contains("swift, concurrency"))
}

@Test func recallMemoryToolReturnsEntries() async throws {
    let tool = RecallMemory()
    let result = try await tool.call(arguments: .init(query: "concurrency"))
    #expect(result.content.contains("concurrency"))
    let data = Data(result.content.utf8)
    let parsed = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    #expect(parsed != nil)
    #expect((parsed?.count ?? 0) >= 1)
}

@Test func saveCheckpointToolReturnsSessionID() async throws {
    let tool = SaveCheckpoint()
    let result = try await tool.call(arguments: .init())
    #expect(result.content.contains("Checkpoint saved"))
    #expect(result.content.contains("Session ID"))
}

@Test func generateResearchReportToolProducesMarkdown() async throws {
    let tool = GenerateResearchReport()
    let result = try await tool.call(arguments: .init(
        topic: "Swift Concurrency Patterns",
        findings: "1. Actors provide data isolation.\n2. Sendable ensures safe transfer."
    ))
    #expect(result.content.contains("# Research Report: Swift Concurrency Patterns"))
    #expect(result.content.contains("## Findings"))
    #expect(result.content.contains("Actors provide data isolation"))
    #expect(result.content.contains("## Conclusion"))
}

// MARK: - Live Integration Tests

@Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTSYNAPSE_LIVE_TESTS"] != nil))
func researchAssistantLiveResponse() async throws {
    let config = try AgentConfiguration(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "nvidia/nemotron-3-nano-4b"
    )
    let agent = try ResearchAssistant(configuration: config)
    let result = try await agent.run(goal: "Research the benefits of Swift concurrency and generate a brief report")
    #expect(!result.isEmpty)

    let status = await agent.status
    guard case .completed = status else {
        Issue.record("Expected .completed status, got \(status)")
        return
    }

    let entries = await agent.transcript.entries
    #expect(entries.count >= 4)
}
