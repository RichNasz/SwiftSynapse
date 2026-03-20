// Generated strictly from Agents/SimpleEcho/CodeGen/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Testing
@testable import SimpleEchoAgent

@Test func simpleEchoProducesExpectedTranscript() async throws {
    let agent = SimpleEcho()
    let result = try await agent.run(goal: "test")
    #expect(result == "Echo from SwiftSynapse: test")
    let entries = await agent.transcript
    #expect(entries.count == 2)
    guard case .userMessage(let userText) = entries[0] else {
        Issue.record("Expected userMessage at index 0, got \(entries[0])")
        return
    }
    #expect(userText == "test")
    guard case .assistantMessage(let assistantText) = entries[1] else {
        Issue.record("Expected assistantMessage at index 1, got \(entries[1])")
        return
    }
    #expect(assistantText == "Echo from SwiftSynapse: test")
    let status = await agent.status
    #expect(status == .completed)
}

@Test func simpleEchoThrowsOnEmptyGoal() async {
    let agent = SimpleEcho()
    await #expect(throws: SimpleEcho.SimpleEchoError.self) {
        try await agent.run(goal: "")
    }
    let status = await agent.status
    #expect(status == .failed)
}
