// Generated strictly from Agents/ToolUsingAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import Testing
import SwiftSynapseMacrosClient
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
    await #expect(throws: ToolUsingAgentError.self) {
        try await agent.execute(goal: "")
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

@Test func calculatorToolReturnsResult() throws {
    let data = Data(#"{"expression":"10 + 5"}"#.utf8)
    let result = try ToolUsingAgent.calculate(data: data)
    #expect(result == "15.0")
}

@Test func calculatorToolDivision() throws {
    let data = Data(#"{"expression":"144 / 12"}"#.utf8)
    let result = try ToolUsingAgent.calculate(data: data)
    #expect(result == "12.0")
}

@Test func converterToolMilesToKilometers() throws {
    let data = Data(#"{"value":100,"fromUnit":"miles","toUnit":"kilometers"}"#.utf8)
    let result = try ToolUsingAgent.convertUnit(data: data)
    #expect(result == "160.9344")
}

@Test func converterToolCelsiusToFahrenheit() throws {
    let data = Data(#"{"value":100,"fromUnit":"celsius","toUnit":"fahrenheit"}"#.utf8)
    let result = try ToolUsingAgent.convertUnit(data: data)
    #expect(result == "212.0000")
}

@Test func converterToolInvalidUnitThrows() {
    let data = Data(#"{"value":100,"fromUnit":"parsecs","toUnit":"kilometers"}"#.utf8)
    #expect(throws: ToolUsingAgentError.self) {
        _ = try ToolUsingAgent.convertUnit(data: data)
    }
}

@Test func formatNumberTool() throws {
    let data = Data(#"{"value":3.14159265,"decimalPlaces":2}"#.utf8)
    let result = try ToolUsingAgent.formatNumber(data: data)
    #expect(result == "3.14")
}

@Test func formatNumberToolClamps() throws {
    let data = Data(#"{"value":3.14,"decimalPlaces":15}"#.utf8)
    let result = try ToolUsingAgent.formatNumber(data: data)
    // Should clamp to 10 decimal places
    #expect(result == "3.1400000000")
}

// MARK: - Live Integration Tests

@Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTSYNAPSE_LIVE_TESTS"] != nil))
func toolUsingAgentLiveResponse() async throws {
    let agent = try ToolUsingAgent(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "nvidia/nemotron-3-nano"
    )
    let result = try await agent.execute(goal: "Convert 100 miles to kilometers")
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
