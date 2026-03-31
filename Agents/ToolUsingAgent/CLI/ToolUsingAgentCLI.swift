// Generated strictly from Agents/ToolUsingAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import ArgumentParser
import ToolUsingAgentAgent
import SwiftSynapseMacrosClient

@main
struct ToolUsingAgentCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tool-using-agent",
        abstract: "Send a math or unit-conversion request to an LLM with tool dispatch."
    )

    @Argument(help: "A natural-language math or unit-conversion request.")
    var goal: String

    @Option(name: .long, help: "Full URL of an Open Responses API endpoint. Falls back to SWIFTSYNAPSE_SERVER_URL env var.")
    var serverURL: String?

    @Option(name: .long, help: "Model identifier (e.g. llama3, gpt-4o). Falls back to SWIFTSYNAPSE_MODEL env var.")
    var model: String?

    @Option(name: .long, help: "Optional API key for authentication. Falls back to SWIFTSYNAPSE_API_KEY env var.")
    var apiKey: String?

    func run() async throws {
        let config = try AgentConfiguration.fromEnvironment(overrides: .init(
            serverURL: serverURL,
            modelName: model,
            apiKey: apiKey
        ))
        let agent = try ToolUsingAgent(configuration: config)
        let result = try await agent.execute(goal: goal)
        print(result)
    }
}
