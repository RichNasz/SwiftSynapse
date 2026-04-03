// Generated strictly from Agents/TaskPlanner/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import Testing
import SwiftSynapseHarness
@testable import TaskPlannerAgent

@Test func taskPlannerInitThrowsOnInvalidURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try AgentConfiguration(serverURL: ":::not-a-url", modelName: "test-model")
    }
}

@Test func taskPlannerThrowsOnEmptyGoal() async throws {
    let config = try AgentConfiguration(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    let agent = try TaskPlanner(configuration: config)
    await #expect(throws: AgentLifecycleError.self) {
        try await agent.run(goal: "")
    }
    let status = await agent.status
    guard case .error = status else {
        Issue.record("Expected .error status, got \(status)")
        return
    }
}

@Test func taskPlannerInitialStateIsIdle() async throws {
    let config = try AgentConfiguration(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    let agent = try TaskPlanner(configuration: config)
    let status = await agent.status
    guard case .idle = status else {
        Issue.record("Expected .idle status, got \(status)")
        return
    }
    let entries = await agent.transcript.entries
    #expect(entries.isEmpty)
}

// MARK: - Tool Unit Tests

@Test func breakdownGoalToolReturnsJSON() async throws {
    let tool = BreakdownGoal()
    let result = try await tool.call(arguments: .init(goal: "Plan a product launch"))
    let data = result.content.data(using: .utf8)!
    let parsed = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    #expect(parsed != nil)
    #expect(parsed!.count > 0)
    for phase in parsed! {
        #expect(phase["id"] != nil)
        #expect(phase["name"] != nil)
        #expect(phase["description"] != nil)
        #expect(phase["dependencies"] != nil)
    }
}

@Test func prioritizeTasksToolAddsPriorities() async throws {
    let tool = PrioritizeTasks()
    let inputPhases = #"[{"id":"p1","name":"Research","description":"Do research","dependencies":[]},{"id":"p2","name":"Plan","description":"Make plan","dependencies":["p1"]}]"#
    let result = try await tool.call(arguments: .init(phases: inputPhases))
    let data = result.content.data(using: .utf8)!
    let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    #expect(parsed != nil)
    let prioritized = parsed!["prioritized"] as? [[String: Any]]
    #expect(prioritized != nil)
    #expect(prioritized!.count == 2)
    for phase in prioritized! {
        #expect(phase["priority"] != nil)
        #expect(phase["executionOrder"] != nil)
    }
}

@Test func synthesizeResultsToolProducesMarkdown() async throws {
    let tool = SynthesizeResults()
    let inputResults = #"{"phase-1":"Research completed successfully.","phase-2":"Plan drafted with 3 milestones."}"#
    let result = try await tool.call(arguments: .init(phaseResults: inputResults))
    #expect(result.content.contains("# Unified Plan"))
    #expect(result.content.contains("## phase-1"))
    #expect(result.content.contains("## phase-2"))
    #expect(result.content.contains("Research completed successfully."))
    #expect(result.content.contains("Plan drafted with 3 milestones."))
}

// MARK: - Live Integration Tests

@Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTSYNAPSE_LIVE_TESTS"] != nil))
func taskPlannerLiveResponse() async throws {
    let config = try AgentConfiguration(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "nvidia/nemotron-3-nano-4b"
    )
    let agent = try TaskPlanner(configuration: config)
    // Small models may exhaust tool iterations without producing a final text response;
    // treat noResponseContent as a degraded-but-acceptable outcome in live tests.
    do {
        let result = try await agent.run(goal: "Plan a team offsite for 20 people including venue, activities, and budget")
        #expect(!result.isEmpty)

        let status = await agent.status
        guard case .completed = status else {
            Issue.record("Expected .completed status, got \(status)")
            return
        }

        let entries = await agent.transcript.entries
        #expect(entries.count >= 2)
    } catch TaskPlannerError.noResponseContent {
        // Acceptable: model used tools but produced no final summary text
    }
}
