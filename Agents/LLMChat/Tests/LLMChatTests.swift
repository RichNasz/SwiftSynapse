// Generated strictly from Agents/LLMChat/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Testing
@testable import LLMChatAgent

@Test func llmChatInitThrowsOnInvalidURL() {
    #expect(throws: LLMChatError.self) {
        _ = try LLMChat(serverURL: ":::not-a-url", modelName: "test-model")
    }
}

@Test func llmChatInitThrowsOnEmptyURL() {
    #expect(throws: LLMChatError.self) {
        _ = try LLMChat(serverURL: "", modelName: "test-model")
    }
}

@Test func llmChatRunThrowsOnEmptyGoal() async throws {
    let agent = try LLMChat(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    await #expect(throws: LLMChatError.self) {
        try await agent.run(goal: "")
    }
    let status = await agent.status
    #expect(status == .failed)
}

@Test func llmChatInitialStateIsIdle() async throws {
    let agent = try LLMChat(serverURL: "http://127.0.0.1:1234/v1/responses", modelName: "test-model")
    let status = await agent.status
    #expect(status == .idle)
    let transcript = await agent.transcript
    #expect(transcript.isEmpty)
    let isRunning = await agent.isRunning
    #expect(!isRunning)
}
