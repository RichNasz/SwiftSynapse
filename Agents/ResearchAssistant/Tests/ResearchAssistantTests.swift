// Generated strictly from Agents/ResearchAssistant/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import Testing
import SwiftSynapseHarness
@testable import ResearchAssistantAgent

@Test func researchAssistantInitThrowsOnInvalidURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try ResearchAssistant(serverURL: ":::not-a-url", modelName: "test-model")
    }
}

@Test func researchAssistantInitThrowsOnEmptyURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try ResearchAssistant(serverURL: "", modelName: "test-model")
    }
}

@Test func researchAssistantThrowsOnEmptyGoal() async throws {
    let agent = try ResearchAssistant(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
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
    let agent = try ResearchAssistant(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
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
    let tool = SearchWebTool()
    let result = try await tool.execute(input: .init(query: "Swift concurrency", maxResults: 3))
    #expect(result.contains("Result 1"))
    #expect(result.contains("Swift concurrency"))
    // Validate JSON structure
    let data = Data(result.utf8)
    let parsed = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    #expect(parsed?.count == 3)
}

@Test func readDocumentToolReturnsContent() async throws {
    let tool = ReadDocumentTool()
    let result = try await tool.execute(input: .init(url: "https://example.com/paper.pdf"))
    #expect(result.contains("Document content extracted"))
    #expect(result.contains("https://example.com/paper.pdf"))
}

@Test func saveMemoryToolReturnsConfirmation() async throws {
    let tool = SaveMemoryTool()
    let result = try await tool.execute(input: .init(
        content: "Key finding about Swift actors",
        category: "finding",
        tags: ["swift", "concurrency"]
    ))
    #expect(result.contains("Memory saved"))
    #expect(result.contains("category: finding"))
    #expect(result.contains("swift, concurrency"))
}

@Test func recallMemoryToolReturnsEntries() async throws {
    let tool = RecallMemoryTool()
    let result = try await tool.execute(input: .init(query: "concurrency"))
    #expect(result.contains("concurrency"))
    // Validate JSON structure
    let data = Data(result.utf8)
    let parsed = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    #expect(parsed != nil)
    #expect((parsed?.count ?? 0) >= 1)
}

@Test func generateReportToolProducesMarkdown() async throws {
    let tool = GenerateReportTool()
    let result = try await tool.execute(input: .init(
        topic: "Swift Concurrency Patterns",
        findings: "1. Actors provide data isolation.\n2. Sendable ensures safe transfer."
    ))
    #expect(result.contains("# Research Report: Swift Concurrency Patterns"))
    #expect(result.contains("## Findings"))
    #expect(result.contains("Actors provide data isolation"))
    #expect(result.contains("## Conclusion"))
}

// MARK: - Tool Registry Tests

@Test func toolRegistryDispatchesSearchWeb() async throws {
    let registry = ToolRegistry()
    registry.register(SearchWebTool())

    let result = try await registry.dispatch(
        name: "searchWeb",
        callId: "test-1",
        arguments: #"{"query":"test query","maxResults":2}"#
    )
    #expect(result.success)
    #expect(result.output.contains("Result 1"))
}

@Test func toolRegistryDispatchesGenerateReport() async throws {
    let registry = ToolRegistry()
    registry.register(GenerateReportTool())

    let result = try await registry.dispatch(
        name: "generateReport",
        callId: "test-2",
        arguments: #"{"topic":"AI Safety","findings":"Finding one."}"#
    )
    #expect(result.success)
    #expect(result.output.contains("# Research Report: AI Safety"))
}

// MARK: - Live Integration Tests

@Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTSYNAPSE_LIVE_TESTS"] != nil))
func researchAssistantLiveResponse() async throws {
    let agent = try ResearchAssistant(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "nvidia/nemotron-3-nano"
    )
    let result = try await agent.run(goal: "Research the benefits of Swift concurrency and generate a brief report")
    #expect(!result.isEmpty)

    let status = await agent.status
    guard case .completed = status else {
        Issue.record("Expected .completed status, got \(status)")
        return
    }

    let entries = await agent.transcript.entries
    // Should have at least userMessage + toolCall + toolResult + assistantMessage
    #expect(entries.count >= 4)
}
