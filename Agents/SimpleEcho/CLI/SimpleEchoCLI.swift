// Generated strictly from Agents/SimpleEcho/specs/Overview.md + shared CodeGenSpecs/
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
        let result = try await agent.run(goal: goal)
        print(result)
    }
}
