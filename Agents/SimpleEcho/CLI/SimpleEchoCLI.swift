// Generated strictly from Agents/SimpleEcho/CodeGen/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import ArgumentParser
import SimpleEchoAgent

@main
struct SimpleEchoCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "simple-echo",
        abstract: "Run the SimpleEcho agent with a goal string."
    )

    @Argument(help: "The goal string to echo back.")
    var goal: String

    func run() async throws {
        let agent = SimpleEcho()
        // Interact with the agent the same way a SwiftUI view would:
        // call run, then read observable status and transcript
        let result = try await agent.run(goal: goal)
        print(result)

        // The agent's transcript and status are also available for richer output:
        // await agent.transcript, await agent.status
    }
}
