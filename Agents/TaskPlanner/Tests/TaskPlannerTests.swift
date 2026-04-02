// Generated strictly from Agents/TaskPlanner/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import Testing
import SwiftSynapseHarness
@testable import TaskPlannerAgent

@Test func taskPlannerInitThrowsOnInvalidURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try TaskPlanner(serverURL: ":::not-a-url", modelName: "test-model")
    }
}

@Test func taskPlannerInitThrowsOnEmptyURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try TaskPlanner(serverURL: "", modelName: "test-model")
    }
}

@Test func taskPlannerThrowsOnEmptyGoal() async throws {
    let agent = try TaskPlanner(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
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
    let agent = try TaskPlanner(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
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
    let tool = BreakdownGoalTool()
    let result = try await tool.execute(input: .init(goal: "Plan a product launch"))
    // Verify the result is valid JSON
    let data = result.data(using: .utf8)!
    let parsed = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
    #expect(parsed != nil)
    #expect(parsed!.count > 0)
    // Each phase should have id, name, description, dependencies
    for phase in parsed! {
        #expect(phase["id"] != nil)
        #expect(phase["name"] != nil)
        #expect(phase["description"] != nil)
        #expect(phase["dependencies"] != nil)
    }
}

@Test func prioritizeTasksToolAddsPriorities() async throws {
    let tool = PrioritizeTasksTool()
    let inputPhases = #"[{"id":"p1","name":"Research","description":"Do research","dependencies":[]},{"id":"p2","name":"Plan","description":"Make plan","dependencies":["p1"]}]"#
    let result = try await tool.execute(input: .init(phases: inputPhases))
    // Verify the result is valid JSON with priority scores
    let data = result.data(using: .utf8)!
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
    let tool = SynthesizeResultsTool()
    let inputResults = #"{"phase-1":"Research completed successfully.","phase-2":"Plan drafted with 3 milestones."}"#
    let result = try await tool.execute(input: .init(phaseResults: inputResults))
    // Verify the result is Markdown
    #expect(result.contains("# Unified Plan"))
    #expect(result.contains("## phase-1"))
    #expect(result.contains("## phase-2"))
    #expect(result.contains("Research completed successfully."))
    #expect(result.contains("Plan drafted with 3 milestones."))
}

// MARK: - Tool Registry Tests

@Test func toolRegistryHasAllTools() async throws {
    let registry = ToolRegistry()
    registry.register(BreakdownGoalTool())
    registry.register(PrioritizeTasksTool())
    registry.register(SynthesizeResultsTool())

    // Verify all 3 tools are registered by dispatching to each
    let breakdownResult = try await registry.dispatch(
        name: "breakdownGoal",
        callId: "test-1",
        arguments: #"{"goal":"Test goal"}"#
    )
    #expect(breakdownResult.success)

    let prioritizeResult = try await registry.dispatch(
        name: "prioritizeTasks",
        callId: "test-2",
        arguments: #"{"phases":"[{\"id\":\"p1\",\"name\":\"Test\",\"description\":\"Test\",\"dependencies\":[]}]"}"#
    )
    #expect(prioritizeResult.success)

    let synthesizeResult = try await registry.dispatch(
        name: "synthesizeResults",
        callId: "test-3",
        arguments: #"{"phaseResults":"{\"p1\":\"Done\"}"}"#
    )
    #expect(synthesizeResult.success)
}

// MARK: - Live Integration Tests

@Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTSYNAPSE_LIVE_TESTS"] != nil))
func taskPlannerLiveResponse() async throws {
    let agent = try TaskPlanner(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "nvidia/nemotron-3-nano"
    )
    let result = try await agent.run(goal: "Plan a team offsite for 20 people including venue, activities, and budget")
    #expect(!result.isEmpty)

    let status = await agent.status
    guard case .completed = status else {
        Issue.record("Expected .completed status, got \(status)")
        return
    }

    let entries = await agent.transcript.entries
    #expect(entries.count >= 4)
}
