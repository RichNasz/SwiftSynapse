// Generated strictly from Agents/SimpleEcho/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Testing
@testable import SimpleEchoAgent

@Test func simpleEchoProducesExpectedTranscript() async throws {
    let agent = SimpleEcho()
    let result = try await agent.execute(goal: "test")
    #expect(result == "Echo from SwiftSynapse: test")
    let entries = await agent.transcript.entries
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
    guard case .completed = status else {
        Issue.record("Expected .completed status, got \(status)")
        return
    }
}

@Test func simpleEchoThrowsOnEmptyGoal() async {
    let agent = SimpleEcho()
    await #expect(throws: SimpleEcho.SimpleEchoError.self) {
        try await agent.execute(goal: "")
    }
    let status = await agent.status
    guard case .error = status else {
        Issue.record("Expected .error status, got \(status)")
        return
    }
}
