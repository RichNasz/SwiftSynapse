// Generated strictly from Agents/PRReviewer/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import Testing
import SwiftSynapseHarness
@testable import PRReviewerAgent

@Test func prReviewerInitThrowsOnInvalidURL() {
    #expect(throws: AgentConfigurationError.self) {
        _ = try AgentConfiguration(serverURL: ":::not-a-url", modelName: "test-model")
    }
}

@Test func prReviewerThrowsOnEmptyGoal() async throws {
    let config = try AgentConfiguration(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    let agent = try PRReviewer(configuration: config)
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
    let config = try AgentConfiguration(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    let agent = try PRReviewer(configuration: config)
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
    let tool = AnalyzeSwiftStyle()
    let code = "let value = optionalValue!"
    let result = try await tool.call(arguments: .init(code: code))
    #expect(result.content.contains("Force unwrap"))
}

@Test func analyzeSwiftStyleToolDetectsLongLine() async throws {
    let tool = AnalyzeSwiftStyle()
    let longLine = "let x = " + String(repeating: "a", count: 120)
    let result = try await tool.call(arguments: .init(code: longLine))
    #expect(result.content.contains("120 characters") || result.content.contains("exceeds"))
}

@Test func analyzeSwiftStyleToolDetectsMissingAccessControl() async throws {
    let tool = AnalyzeSwiftStyle()
    let code = "func doSomething() { }"
    let result = try await tool.call(arguments: .init(code: code))
    #expect(result.content.contains("access control"))
}

@Test func checkSecurityToolDetectsHardcodedKey() async throws {
    let tool = CheckSecurityPatterns()
    let code = #"let apiKey = "sk-abc123456789""#
    let result = try await tool.call(arguments: .init(code: code))
    #expect(result.content.contains("key") || result.content.contains("API"))
}

@Test func checkSecurityToolDetectsHardcodedPassword() async throws {
    let tool = CheckSecurityPatterns()
    let code = #"let password = "admin123""#
    let result = try await tool.call(arguments: .init(code: code))
    #expect(result.content.contains("password") || result.content.contains("Password"))
}

@Test func formatReviewToolProducesMarkdown() async throws {
    let tool = FormatReview()
    let result = try await tool.call(arguments: .init(
        findings: "[{\"line\": \"1\", \"severity\": \"warning\", \"message\": \"Force unwrap\"}]",
        patches: "No patches suggested."
    ))
    #expect(result.content.contains("## Code Review Summary"))
    #expect(result.content.contains("Findings"))
    #expect(result.content.contains("Patches"))
}

@Test func suggestPatchToolFormatsCorrectly() async throws {
    let tool = SuggestPatch()
    let result = try await tool.call(arguments: .init(
        file: "Sources/App.swift",
        issue: "Force unwrap on line 10",
        suggestion: "guard let value = optionalValue else { return }"
    ))
    #expect(result.content.contains("Sources/App.swift"))
    #expect(result.content.contains("Force unwrap on line 10"))
    #expect(result.content.contains("guard let value"))
}

@Test func fetchDiffToolReturnsSimulatedDiff() async throws {
    let tool = FetchDiff()
    let result = try await tool.call(arguments: .init(source: "42"))
    #expect(result.content.contains("--- a/"))
    #expect(result.content.contains("+++ b/"))
}

// MARK: - Live Integration Tests

@Test(.enabled(if: ProcessInfo.processInfo.environment["SWIFTSYNAPSE_LIVE_TESTS"] != nil))
func prReviewerLiveResponse() async throws {
    let config = try AgentConfiguration(
        serverURL: "http://127.0.0.1:1234/v1/responses",
        modelName: "nvidia/nemotron-3-nano-4b"
    )
    let agent = try PRReviewer(configuration: config)
    // Small models may exhaust tool iterations without producing a final text response;
    // treat noResponseContent as a degraded-but-acceptable outcome in live tests.
    do {
        let result = try await agent.run(goal: "Review the latest diff for Swift style and security issues")
        #expect(!result.isEmpty)

        let status = await agent.status
        guard case .completed = status else {
            Issue.record("Expected .completed status, got \(status)")
            return
        }

        let entries = await agent.transcript.entries
        #expect(entries.count >= 2)
    } catch PRReviewerError.noResponseContent {
        // Acceptable: model used tools but produced no final summary text
    }
}
