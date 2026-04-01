// Generated strictly from Agents/ToolUsingAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import Testing
import SwiftSynapseHarness
@testable import ToolUsingAgentAgent

@Test func toolUsingAgentInitThrowsOnInvalidURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try ToolUsingAgent(serverURL: ":::not-a-url", modelName: "test-model")
    }
}

@Test func toolUsingAgentInitThrowsOnEmptyURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try ToolUsingAgent(serverURL: "", modelName: "test-model")
    }
}

@Test func toolUsingAgentThrowsOnEmptyGoal() async throws {
    let agent = try ToolUsingAgent(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    await #expect(throws: AgentLifecycleError.self) {
        try await agent.run(goal: "")
    }
    let status = await agent.status
    guard case .error = status else {
        Issue.record("Expected .error status, got \(status)")
        return
    }
}

@Test func toolUsingAgentInitialStateIsIdle() async throws {
    let agent = try ToolUsingAgent(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    let status = await agent.status
    guard case .idle = status else {
        Issue.record("Expected .idle status, got \(status)")
        return
    }
    let entries = await agent.transcript.entries
    #expect(entries.isEmpty)
}

// MARK: - Tool Unit Tests

@Test func calculatorToolReturnsResult() async throws {
    let tool = CalculateTool()
    let result = try await tool.execute(input: .init(expression: "10 + 5"))
    #expect(result == "15.0")
}

@Test func calculatorToolDivision() async throws {
    let tool = CalculateTool()
    let result = try await tool.execute(input: .init(expression: "144 / 12"))
    #expect(result == "12.0")
}

@Test func converterToolMilesToKilometers() async throws {
    let tool = ConvertUnitTool()
    let result = try await tool.execute(input: .init(value: 100, fromUnit: "miles", toUnit: "kilometers"))
    #expect(result == "160.9344")
}

@Test func converterToolCelsiusToFahrenheit() async throws {
    let tool = ConvertUnitTool()
    let result = try await tool.execute(input: .init(value: 100, fromUnit: "celsius", toUnit: "fahrenheit"))
    #expect(result == "212.0000")
}

@Test func converterToolInvalidUnitThrows() async {
    let tool = ConvertUnitTool()
    await #expect(throws: ToolUsingAgentError.self) {
        _ = try await tool.execute(input: .init(value: 100, fromUnit: "parsecs", toUnit: "kilometers"))
    }
}

@Test func formatNumberTool() async throws {
    let tool = FormatNumberTool()
    let result = try await tool.execute(input: .init(value: 3.14159265, decimalPlaces: 2))
    #expect(result == "3.14")
}

@Test func formatNumberToolClamps() async throws {
    let tool = FormatNumberTool()
    let result = try await tool.execute(input: .init(value: 3.14, decimalPlaces: 15))
    // Should clamp to 10 decimal places
    #expect(result == "3.1400000000")
}

// MARK: - Tool Registry Tests

@Test func toolRegistryDispatchesCorrectly() async throws {
    let registry = ToolRegistry()
    registry.register(CalculateTool())
    registry.register(ConvertUnitTool())
    registry.register(FormatNumberTool())

    let result = try await registry.dispatch(
        name: "calculate",
        callId: "test-1",
        arguments: #"{"expression":"2 + 2"}"#
    )
    #expect(result.success)
    #expect(result.output == "4.0")
}

@Test func toolRegistryThrowsOnUnknownTool() async {
    let registry = ToolRegistry()
    registry.register(CalculateTool())

    await #expect(throws: ToolDispatchError.self) {
        _ = try await registry.dispatch(
            name: "nonexistent",
            callId: "test-1",
            arguments: "{}"
        )
    }
}

// MARK: - Live Integration Tests

@Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTSYNAPSE_LIVE_TESTS"] != nil))
func toolUsingAgentLiveResponse() async throws {
    let agent = try ToolUsingAgent(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "nvidia/nemotron-3-nano"
    )
    let result = try await agent.run(goal: "Convert 100 miles to kilometers")
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
