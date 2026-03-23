// Generated strictly from Agents/LLMChatPersonas/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Testing
@testable import LLMChatPersonasAgent

@Test func initThrowsOnInvalidURL() {
    #expect(throws: LLMChatPersonasError.self) {
        _ = try LLMChatPersonas(serverURL: ":::not-a-url", modelName: "test-model")
    }
}

@Test func initThrowsOnEmptyURL() {
    #expect(throws: LLMChatPersonasError.self) {
        _ = try LLMChatPersonas(serverURL: "", modelName: "test-model")
    }
}

@Test func runThrowsOnEmptyGoal() async throws {
    let agent = try LLMChatPersonas(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    await #expect(throws: LLMChatPersonasError.self) {
        try await agent.execute(goal: "")
    }
    let status = await agent.status
    guard case .error = status else {
        Issue.record("Expected .error status, got \(status)")
        return
    }
}

@Test func initialStateIsIdle() async throws {
    let agent = try LLMChatPersonas(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    let status = await agent.status
    guard case .idle = status else {
        Issue.record("Expected .idle status, got \(status)")
        return
    }
    let entries = await agent.transcript.entries
    #expect(entries.isEmpty)
}
