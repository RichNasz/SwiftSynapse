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
        try await agent.run(goal: "")
    }
    let status = await agent.status
    #expect(status == .failed)
}

@Test func initialStateIsIdle() async throws {
    let agent = try LLMChatPersonas(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    let status = await agent.status
    #expect(status == .idle)
    let transcript = await agent.transcript
    #expect(transcript.isEmpty)
    let isRunning = await agent.isRunning
    #expect(!isRunning)
}
