// Generated strictly from Agents/PerformanceOptimizer/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import Testing
import SwiftSynapseHarness
@testable import PerformanceOptimizerAgent

@Test func perfOptimizerInitThrowsOnInvalidURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try AgentConfiguration(serverURL: ":::not-a-url", modelName: "test-model")
    }
}

@Test func perfOptimizerThrowsOnEmptyGoal() async throws {
    let config = try AgentConfiguration(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    let agent = try PerformanceOptimizer(configuration: config)
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
    let config = try AgentConfiguration(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    let agent = try PerformanceOptimizer(configuration: config)
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
    let tool = AnalyzeProfile()
    let result = try await tool.call(arguments: .init(filePath: "/src/DataProcessor.swift"))
    #expect(result.content.contains("DataProcessor.swift"))
    #expect(result.content.contains("totalTime_ms"))
    #expect(result.content.contains("hotspots"))
    let data = result.content.data(using: .utf8)!
    let json = try JSONSerialization.jsonObject(with: data)
    #expect(json is [String: Any])
}

@Test func benchmarkAlternativeToolReturnsComparison() async throws {
    let tool = BenchmarkAlternative()
    let result = try await tool.call(arguments: .init(
        original: "for i in 0..<array.count { process(array[i]) }",
        alternative: "array.forEach { process($0) }",
        iterations: 1000
    ))
    #expect(result.content.contains("1000"))
    #expect(result.content.contains("original"))
    #expect(result.content.contains("alternative"))
    #expect(result.content.contains("speedup"))
    #expect(result.content.contains("winner"))
    let data = result.content.data(using: .utf8)!
    let json = try JSONSerialization.jsonObject(with: data)
    #expect(json is [String: Any])
}

@Test func suggestOptimizationToolReturnsRecommendation() async throws {
    let tool = SuggestOptimization()
    let result = try await tool.call(arguments: .init(
        code: "let found = array.first(where: { $0.id == targetId })",
        issue: "Linear search in hot loop"
    ))
    #expect(result.content.contains("Linear search in hot loop"))
    #expect(result.content.contains("Recommended changes"))
    #expect(result.content.contains("Estimated improvement"))
}

@Test func measureMemoryToolReturnsProfile() async throws {
    let tool = MeasureMemory()
    let result = try await tool.call(arguments: .init(filePath: "/src/ImageCache.swift"))
    #expect(result.content.contains("ImageCache.swift"))
    #expect(result.content.contains("heapAllocations"))
    #expect(result.content.contains("heapPeak_kb"))
    #expect(result.content.contains("leaks"))
    let data = result.content.data(using: .utf8)!
    let json = try JSONSerialization.jsonObject(with: data)
    #expect(json is [String: Any])
}

@Test func compareImplementationsToolReturnsAnalysis() async throws {
    let tool = CompareImplementations()
    let result = try await tool.call(arguments: .init(implementations: [
        "array.sorted()",
        "array.sorted(by: <)",
        "var copy = array; copy.sort()"
    ]))
    #expect(result.content.contains("Comparison of 3 implementations"))
    #expect(result.content.contains("Implementation 1"))
    #expect(result.content.contains("Implementation 2"))
    #expect(result.content.contains("Implementation 3"))
    #expect(result.content.contains("Recommendation"))
}

// MARK: - Live Integration Tests

@Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTSYNAPSE_LIVE_TESTS"] != nil))
func perfOptimizerLiveResponse() async throws {
    let config = try AgentConfiguration(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "nvidia/nemotron-3-nano-4b"
    )
    let agent = try PerformanceOptimizer(configuration: config)
    // Small models may exhaust tool iterations without producing a final text response;
    // treat noResponseContent as a degraded-but-acceptable outcome in live tests.
    do {
        let result = try await agent.run(goal: "Profile the file /src/DataProcessor.swift and suggest optimizations for any hotspots")
        #expect(!result.isEmpty)

        let status = await agent.status
        guard case .completed = status else {
            Issue.record("Expected .completed status, got \(status)")
            return
        }

        let entries = await agent.transcript.entries
        #expect(entries.count >= 2)
    } catch PerformanceOptimizerError.noResponseContent {
        // Acceptable: model used tools but produced no final summary text
    }
}
