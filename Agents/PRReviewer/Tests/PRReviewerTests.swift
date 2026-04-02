// Generated strictly from Agents/PRReviewer/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import Testing
import SwiftSynapseHarness
@testable import PRReviewerAgent

@Test func prReviewerInitThrowsOnInvalidURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try PRReviewer(serverURL: ":::not-a-url", modelName: "test-model")
    }
}

@Test func prReviewerInitThrowsOnEmptyURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try PRReviewer(serverURL: "", modelName: "test-model")
    }
}

@Test func prReviewerThrowsOnEmptyGoal() async throws {
    let agent = try PRReviewer(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    await #expect(throws: AgentLifecycleError.self) {
        try await agent.run(goal: "")
    }
    let status = await agent.status
    guard case .error = status else {
        Issue.record("Expected .error status, got \(status)")
        return
    }
}

@Test func prReviewerInitialStateIsIdle() async throws {
    let agent = try PRReviewer(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    let status = await agent.status
    guard case .idle = status else {
        Issue.record("Expected .idle status, got \(status)")
        return
    }
    let entries = await agent.transcript.entries
    #expect(entries.isEmpty)
}

// MARK: - Tool Unit Tests

@Test func analyzeSwiftStyleToolDetectsForceUnwrap() async throws {
    let tool = AnalyzeSwiftStyleTool()
    let code = """
    let value = optionalValue!
    let safe = optionalValue ?? defaultValue
    """
    let result = try await tool.execute(input: .init(code: code))
    #expect(result.contains("Force unwrap"))
}

@Test func analyzeSwiftStyleToolDetectsLongLine() async throws {
    let tool = AnalyzeSwiftStyleTool()
    let longLine = "let x = " + String(repeating: "a", count: 120)
    let result = try await tool.execute(input: .init(code: longLine))
    #expect(result.contains("120 characters"))
}

@Test func analyzeSwiftStyleToolDetectsMissingAccessControl() async throws {
    let tool = AnalyzeSwiftStyleTool()
    let code = "func doSomething() { }"
    let result = try await tool.execute(input: .init(code: code))
    #expect(result.contains("Missing explicit access control"))
}

@Test func checkSecurityToolDetectsHardcodedKey() async throws {
    let tool = CheckSecurityPatternsTool()
    let code = """
    let apiKey = "sk-abc123456789"
    let safeValue = 42
    """
    let result = try await tool.execute(input: .init(code: code))
    #expect(result.contains("API key"))
}

@Test func checkSecurityToolDetectsHardcodedPassword() async throws {
    let tool = CheckSecurityPatternsTool()
    let code = #"let password = "admin123""#
    let result = try await tool.execute(input: .init(code: code))
    #expect(result.contains("password"))
}

@Test func checkSecurityToolDetectsGitHubToken() async throws {
    let tool = CheckSecurityPatternsTool()
    let code = #"let token = "ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx""#
    let result = try await tool.execute(input: .init(code: code))
    #expect(result.contains("GitHub token"))
}

@Test func formatReviewToolProducesMarkdown() async throws {
    let tool = FormatReviewTool()
    let result = try await tool.execute(input: .init(
        findings: "[{\"line\": \"1\", \"severity\": \"warning\", \"message\": \"Force unwrap\"}]",
        patches: "No patches suggested."
    ))
    #expect(result.contains("## Code Review Summary"))
    #expect(result.contains("### Findings"))
    #expect(result.contains("### Suggested Patches"))
    #expect(result.contains("PRReviewer Agent"))
}

@Test func suggestPatchToolFormatsCorrectly() async throws {
    let tool = SuggestPatchTool()
    let result = try await tool.execute(input: .init(
        file: "Sources/App.swift",
        issue: "Force unwrap on line 10",
        suggestion: "guard let value = optionalValue else { return }"
    ))
    #expect(result.contains("Sources/App.swift"))
    #expect(result.contains("Force unwrap on line 10"))
    #expect(result.contains("guard let value"))
}

@Test func fetchDiffToolReturnsSimulatedDiff() async throws {
    let tool = FetchDiffTool()
    let result = try await tool.execute(input: .init(source: "42"))
    #expect(result.contains("--- a/App.swift"))
    #expect(result.contains("+++ b/App.swift"))
}

// MARK: - Tool Registry Tests

@Test func toolRegistryDispatchesCorrectly() async throws {
    let registry = ToolRegistry()
    registry.register(AnalyzeSwiftStyleTool())
    registry.register(CheckSecurityPatternsTool())
    registry.register(FormatReviewTool())

    let code = #"let value = optionalValue!"#
    let result = try await registry.dispatch(
        name: "analyzeSwiftStyle",
        callId: "test-1",
        arguments: #"{"code":"\#(code)"}"#
    )
    #expect(result.success)
    #expect(result.output.contains("Force unwrap"))
}

@Test func toolRegistryThrowsOnUnknownTool() async {
    let registry = ToolRegistry()
    registry.register(FetchDiffTool())

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
func prReviewerLiveResponse() async throws {
    let agent = try PRReviewer(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "nvidia/nemotron-3-nano"
    )
    let result = try await agent.run(goal: "Review the latest diff for Swift style and security issues")
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
