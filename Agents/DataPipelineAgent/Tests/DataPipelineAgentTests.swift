// Generated strictly from Agents/DataPipelineAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import Testing
import SwiftSynapseHarness
@testable import DataPipelineAgentAgent

@Test func dataPipelineInitThrowsOnInvalidURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try DataPipelineAgent(serverURL: ":::not-a-url", modelName: "test-model")
    }
}

@Test func dataPipelineInitThrowsOnEmptyURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try DataPipelineAgent(serverURL: "", modelName: "test-model")
    }
}

@Test func dataPipelineThrowsOnEmptyGoal() async throws {
    let agent = try DataPipelineAgent(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
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
    let agent = try DataPipelineAgent(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
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
    let tool = ReadCSVTool()
    let result = try await tool.execute(input: .init(filePath: "test.csv"))
    // Result should be valid JSON array
    let data = result.data(using: .utf8)!
    let parsed = try JSONSerialization.jsonObject(with: data)
    let array = try #require(parsed as? [[String: Any]])
    #expect(array.count > 0)
    // Each row should have expected keys
    let firstRow = array[0]
    #expect(firstRow["name"] != nil)
    #expect(firstRow["salary"] != nil)
}

@Test func filterCSVToolFiltersData() async throws {
    let tool = FilterCSVTool()
    let inputData = #"[{"name":"Alice","department":"Engineering"},{"name":"Bob","department":"Marketing"},{"name":"Charlie","department":"Engineering"}]"#
    let result = try await tool.execute(input: .init(data: inputData, column: "department", predicate: "Engineering"))
    let data = result.data(using: .utf8)!
    let parsed = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    let array = try #require(parsed)
    #expect(array.count == 2)
}

@Test func aggregateCSVToolSums() async throws {
    let tool = AggregateCSVTool()
    let inputData = #"[{"name":"Alice","salary":100},{"name":"Bob","salary":200},{"name":"Charlie","salary":300}]"#
    let result = try await tool.execute(input: .init(data: inputData, column: "salary", operation: "sum"))
    #expect(result == "600")
}

@Test func queryJSONToolExtractsValue() async throws {
    let tool = QueryJSONTool()
    let inputData = #"{"users":[{"name":"Alice"},{"name":"Bob"}]}"#
    let result = try await tool.execute(input: .init(data: inputData, path: "users.0.name"))
    #expect(result == "Alice")
}

@Test func generateReportToolProducesMarkdown() async throws {
    let tool = GenerateReportTool()
    let sections = #"[{"heading":"Summary","body":"Total revenue: $1M"},{"heading":"Details","body":"Q1: $250K, Q2: $300K"}]"#
    let result = try await tool.execute(input: .init(title: "Quarterly Report", sections: sections))
    #expect(result.contains("# Quarterly Report"))
    #expect(result.contains("## Summary"))
    #expect(result.contains("Total revenue: $1M"))
    #expect(result.contains("## Details"))
}

@Test func toolRegistryHasAllTools() async throws {
    let registry = ToolRegistry()
    registry.register(ReadCSVTool())
    registry.register(FilterCSVTool())
    registry.register(AggregateCSVTool())
    registry.register(QueryJSONTool())
    registry.register(GenerateReportTool())

    let defs = registry.definitions()
    #expect(defs.count == 5)

    let names = Set(defs.map(\.name))
    #expect(names.contains("readCSV"))
    #expect(names.contains("filterCSV"))
    #expect(names.contains("aggregateCSV"))
    #expect(names.contains("queryJSON"))
    #expect(names.contains("generateReport"))
}

// MARK: - Live Integration Tests

@Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTSYNAPSE_LIVE_TESTS"] != nil))
func dataPipelineLiveResponse() async throws {
    let agent = try DataPipelineAgent(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "nvidia/nemotron-3-nano"
    )
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
