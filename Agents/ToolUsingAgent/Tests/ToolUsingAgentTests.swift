// Generated strictly from Agents/ToolUsingAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import Testing
import SwiftSynapseHarness
@testable import ToolUsingAgentAgent

@Test func toolUsingAgentInitThrowsOnInvalidURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try AgentConfiguration(serverURL: ":::not-a-url", modelName: "test-model")
    }
}

@Test func toolUsingAgentInitialStateIsIdle() async throws {
    let config = try AgentConfiguration(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    let agent = try ToolUsingAgent(configuration: config)
    let status = await agent.status
    guard case .idle = status else {
        Issue.record("Expected .idle status, got \(status)")
        return
    }
    let entries = await agent.transcript.entries
    #expect(entries.isEmpty)
}

@Test func toolUsingAgentThrowsOnEmptyGoal() async throws {
    let config = try AgentConfiguration(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    let agent = try ToolUsingAgent(configuration: config)
    await #expect(throws: AgentLifecycleError.self) {
        try await agent.run(goal: "")
    }
    let status = await agent.status
    guard case .error = status else {
        Issue.record("Expected .error status, got \(status)")
        return
    }
}

// MARK: - Tool Unit Tests

@Test func calculateToolReturnsResult() async throws {
    let tool = Calculate()
    let result = try await tool.call(arguments: .init(expression: "2+2"))
    #expect(result.content == "4.0")
}

@Test func calculateToolDivision() async throws {
    let tool = Calculate()
    let result = try await tool.call(arguments: .init(expression: "144/12"))
    #expect(result.content == "12.0")
}

@Test func calculateToolInvalidExpressionThrows() async {
    let tool = Calculate()
    await #expect(throws: ToolUsingAgentError.self) {
        _ = try await tool.call(arguments: .init(expression: "!!!"))
    }
}

@Test func convertUnitMilesToKilometers() async throws {
    let tool = ConvertUnit()
    let result = try await tool.call(arguments: .init(value: 100, fromUnit: "miles", toUnit: "kilometers"))
    #expect(result.content == "160.9344")
}

@Test func convertUnitCelsiusToFahrenheit() async throws {
    let tool = ConvertUnit()
    let result = try await tool.call(arguments: .init(value: 0, fromUnit: "celsius", toUnit: "fahrenheit"))
    #expect(result.content == "32.0000")
}

@Test func convertUnitInvalidUnitThrows() async {
    let tool = ConvertUnit()
    await #expect(throws: ToolUsingAgentError.self) {
        _ = try await tool.call(arguments: .init(value: 100, fromUnit: "parsecs", toUnit: "kilometers"))
    }
}

@Test func formatNumberTool() async throws {
    let tool = FormatNumber()
    let result = try await tool.call(arguments: .init(value: 3.14159, decimalPlaces: 2))
    #expect(result.content == "3.14")
}

@Test func formatNumberToolClamps() async throws {
    let tool = FormatNumber()
    let result = try await tool.call(arguments: .init(value: 3.14, decimalPlaces: 99))
    // decimalPlaces is clamped to 10
    #expect(result.content == "3.1400000000")
}

// MARK: - Live Integration Tests

@Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTSYNAPSE_LIVE_TESTS"] != nil))
func toolUsingAgentLiveResponse() async throws {
    let config = try AgentConfiguration(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "nvidia/nemotron-3-nano-4b"
    )
    let agent = try ToolUsingAgent(configuration: config)
    let result = try await agent.run(goal: "Convert 100 miles to kilometers")
    #expect(!result.isEmpty)

    let status = await agent.status
    guard case .completed = status else {
        Issue.record("Expected .completed status, got \(status)")
        return
    }

    let entries = await agent.transcript.entries
    #expect(entries.count >= 2)
}
