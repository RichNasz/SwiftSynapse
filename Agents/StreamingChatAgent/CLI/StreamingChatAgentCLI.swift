// Generated strictly from Agents/StreamingChatAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import ArgumentParser
import StreamingChatAgentAgent
import SwiftSynapseMacrosClient

@main
struct StreamingChatAgentCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "streaming-chat-agent",
        abstract: "Stream a prompt response from an Open Responses API endpoint token-by-token."
    )

    @Argument(help: "The prompt to send to the LLM.")
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
        let agent = try StreamingChatAgent(configuration: config)
        let result = try await agent.run(goal: goal)
        print(result)
    }
}
