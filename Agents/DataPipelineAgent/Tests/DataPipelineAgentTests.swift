// Generated strictly from Agents/DataPipelineAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import Testing
import SwiftSynapseHarness
@testable import DataPipelineAgentAgent

@Test func dataPipelineInitThrowsOnInvalidURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try AgentConfiguration(serverURL: ":::not-a-url", modelName: "test-model")
    }
}

@Test func dataPipelineThrowsOnEmptyGoal() async throws {
    let config = try AgentConfiguration(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    let agent = try DataPipelineAgent(configuration: config)
    await #expect(throws: AgentLifecycleError.self) {
        try await agent.run(goal: "")
    }
    let status = await agent.status
    guard case .error = status else {
        Issue.record("Expected .error status, got \(status)")
        return
    }
}

@Test func dataPipelineInitialStateIsIdle() async throws {
    let config = try AgentConfiguration(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    let agent = try DataPipelineAgent(configuration: config)
    let status = await agent.status
    guard case .idle = status else {
        Issue.record("Expected .idle status, got \(status)")
        return
    }
    let entries = await agent.transcript.entries
    #expect(entries.isEmpty)
}

// MARK: - Tool Unit Tests

@Test func readCSVToolReturnsJSON() async throws {
    let tool = ReadCSV()
    let result = try await tool.call(arguments: .init(filePath: "test.csv"))
    let data = result.content.data(using: .utf8)!
    let parsed = try JSONSerialization.jsonObject(with: data)
    let array = try #require(parsed as? [[String: Any]])
    #expect(array.count > 0)
    let firstRow = array[0]
    #expect(firstRow["name"] != nil)
    #expect(firstRow["salary"] != nil)
}

@Test func filterCSVToolFiltersData() async throws {
    let tool = FilterCSV()
    let inputData = #"[{"name":"Alice","department":"Engineering"},{"name":"Bob","department":"Marketing"},{"name":"Charlie","department":"Engineering"}]"#
    let result = try await tool.call(arguments: .init(data: inputData, column: "department", predicate: "Engineering"))
    let data = result.content.data(using: .utf8)!
    let parsed = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    let array = try #require(parsed)
    #expect(array.count == 2)
}

@Test func aggregateCSVToolSums() async throws {
    let tool = AggregateCSV()
    let inputData = #"[{"name":"Alice","salary":100},{"name":"Bob","salary":200},{"name":"Charlie","salary":300}]"#
    let result = try await tool.call(arguments: .init(data: inputData, column: "salary", operation: "sum"))
    #expect(result.content == "600")
}

@Test func queryJSONToolExtractsValue() async throws {
    let tool = QueryJSON()
    let inputData = #"{"users":[{"name":"Alice"},{"name":"Bob"}]}"#
    let result = try await tool.call(arguments: .init(data: inputData, path: "users.0.name"))
    #expect(result.content == "Alice")
}

@Test func generatePipelineReportToolProducesMarkdown() async throws {
    let tool = GeneratePipelineReport()
    let sections = #"[{"heading":"Summary","body":"Total revenue: $1M"},{"heading":"Details","body":"Q1: $250K, Q2: $300K"}]"#
    let result = try await tool.call(arguments: .init(title: "Quarterly Report", sections: sections))
    #expect(result.content.contains("# Quarterly Report"))
    #expect(result.content.contains("## Summary"))
    #expect(result.content.contains("Total revenue: $1M"))
    #expect(result.content.contains("## Details"))
}

// MARK: - Live Integration Tests

@Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTSYNAPSE_LIVE_TESTS"] != nil))
func dataPipelineLiveResponse() async throws {
    let config = try AgentConfiguration(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "nvidia/nemotron-3-nano-4b"
    )
    let agent = try DataPipelineAgent(configuration: config)
    let result = try await agent.run(goal: "Read the CSV file at data.csv and sum the salary column")
    #expect(!result.isEmpty)

    let status = await agent.status
    guard case .completed = status else {
        Issue.record("Expected .completed status, got \(status)")
        return
    }

    let entries = await agent.transcript.entries
    #expect(entries.count >= 4)
}
