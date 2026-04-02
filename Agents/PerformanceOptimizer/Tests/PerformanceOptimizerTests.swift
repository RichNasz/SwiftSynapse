// Generated strictly from Agents/PerformanceOptimizer/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import Testing
import SwiftSynapseHarness
@testable import PerformanceOptimizerAgent

@Test func perfOptimizerInitThrowsOnInvalidURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try PerformanceOptimizer(serverURL: ":::not-a-url", modelName: "test-model")
    }
}

@Test func perfOptimizerInitThrowsOnEmptyURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try PerformanceOptimizer(serverURL: "", modelName: "test-model")
    }
}

@Test func perfOptimizerThrowsOnEmptyGoal() async throws {
    let agent = try PerformanceOptimizer(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    await #expect(throws: AgentLifecycleError.self) {
        try await agent.run(goal: "")
    }
    let status = await agent.status
    guard case .error = status else {
        Issue.record("Expected .error status, got \(status)")
        return
    }
}

@Test func perfOptimizerInitialStateIsIdle() async throws {
    let agent = try PerformanceOptimizer(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    let status = await agent.status
    guard case .idle = status else {
        Issue.record("Expected .idle status, got \(status)")
        return
    }
    let entries = await agent.transcript.entries
    #expect(entries.isEmpty)
}

// MARK: - Tool Unit Tests

@Test func analyzeProfileToolReturnsJSON() async throws {
    let tool = AnalyzeProfileTool()
    let result = try await tool.execute(input: .init(filePath: "/src/DataProcessor.swift"))
    #expect(result.contains("\"file\":\"DataProcessor.swift\""))
    #expect(result.contains("\"totalTime_ms\""))
    #expect(result.contains("\"hotspots\""))
    // Verify it is valid JSON
    let data = result.data(using: .utf8)!
    let json = try JSONSerialization.jsonObject(with: data)
    #expect(json is [String: Any])
}

@Test func benchmarkToolReturnsComparison() async throws {
    let tool = BenchmarkAlternativeTool()
    let result = try await tool.execute(input: .init(
        original: "for i in 0..<array.count { process(array[i]) }",
        alternative: "array.forEach { process($0) }",
        iterations: 1000
    ))
    #expect(result.contains("\"iterations\":1000"))
    #expect(result.contains("\"original\""))
    #expect(result.contains("\"alternative\""))
    #expect(result.contains("\"speedup\""))
    #expect(result.contains("\"winner\""))
    // Verify it is valid JSON
    let data = result.data(using: .utf8)!
    let json = try JSONSerialization.jsonObject(with: data)
    #expect(json is [String: Any])
}

@Test func suggestOptimizationToolReturnsCode() async throws {
    let tool = SuggestOptimizationTool()
    let result = try await tool.execute(input: .init(
        code: "let found = array.first(where: { $0.id == targetId })",
        issue: "Linear search in hot loop"
    ))
    #expect(result.contains("Linear search in hot loop"))
    #expect(result.contains("Recommended changes"))
    #expect(result.contains("Estimated improvement"))
}

@Test func measureMemoryToolReturnsProfile() async throws {
    let tool = MeasureMemoryTool()
    let result = try await tool.execute(input: .init(filePath: "/src/ImageCache.swift"))
    #expect(result.contains("\"file\":\"ImageCache.swift\""))
    #expect(result.contains("\"heapAllocations\""))
    #expect(result.contains("\"heapPeak_kb\""))
    #expect(result.contains("\"leaks\""))
    // Verify it is valid JSON
    let data = result.data(using: .utf8)!
    let json = try JSONSerialization.jsonObject(with: data)
    #expect(json is [String: Any])
}

@Test func compareImplementationsToolReturnsAnalysis() async throws {
    let tool = CompareImplementationsTool()
    let result = try await tool.execute(input: .init(implementations: [
        "array.sorted()",
        "array.sorted(by: <)",
        "var copy = array; copy.sort()"
    ]))
    #expect(result.contains("Comparison of 3 implementations"))
    #expect(result.contains("Implementation 1"))
    #expect(result.contains("Implementation 2"))
    #expect(result.contains("Implementation 3"))
    #expect(result.contains("Recommendation"))
}

// MARK: - Tool Registry Tests

@Test func toolRegistryDispatchesAnalyzeProfile() async throws {
    let registry = ToolRegistry()
    registry.register(AnalyzeProfileTool())

    let result = try await registry.dispatch(
        name: "analyzeProfile",
        callId: "test-1",
        arguments: #"{"filePath":"/src/Main.swift"}"#
    )
    #expect(result.success)
    #expect(result.output.contains("Main.swift"))
}

@Test func toolRegistryDispatchesBenchmark() async throws {
    let registry = ToolRegistry()
    registry.register(BenchmarkAlternativeTool())

    let result = try await registry.dispatch(
        name: "benchmarkAlternative",
        callId: "test-2",
        arguments: #"{"original":"code_a","alternative":"code_b","iterations":100}"#
    )
    #expect(result.success)
    #expect(result.output.contains("\"iterations\":100"))
}

// MARK: - Live Integration Tests

@Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTSYNAPSE_LIVE_TESTS"] != nil))
func perfOptimizerLiveResponse() async throws {
    let agent = try PerformanceOptimizer(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "nvidia/nemotron-3-nano"
    )
    let result = try await agent.run(goal: "Profile the file /src/DataProcessor.swift and suggest optimizations for any hotspots")
    #expect(!result.isEmpty)

    let status = await agent.status
    guard case .completed = status else {
        Issue.record("Expected .completed status, got \(status)")
        return
    }

    let entries = await agent.transcript.entries
    #expect(entries.count >= 4)
}
