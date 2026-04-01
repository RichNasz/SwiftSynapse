// Generated strictly from Agents/RetryingLLMChatAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import ArgumentParser
import RetryingLLMChatAgentAgent
import SwiftSynapseMacrosClient

@main
struct RetryingLLMChatAgentCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "retrying-llm-chat-agent",
        abstract: "Send a prompt to an Open Responses API endpoint with automatic retry on transient failures."
    )

    @Argument(help: "The prompt to send to the LLM.")
    var goal: String

    @Option(name: .long, help: "Full URL of an Open Responses API endpoint. Falls back to SWIFTSYNAPSE_SERVER_URL env var.")
    var serverURL: String?

    @Option(name: .long, help: "Model identifier (e.g. llama3, gpt-4o). Falls back to SWIFTSYNAPSE_MODEL env var.")
    var model: String?

    @Option(name: .long, help: "Optional API key for authentication. Falls back to SWIFTSYNAPSE_API_KEY env var.")
    var apiKey: String?

    @Option(name: .long, help: "Maximum number of retry attempts (1–10, default 3).")
    var maxRetries: Int = 3

    func run() async throws {
        let config = try AgentConfiguration.fromEnvironment(overrides: .init(
            serverURL: serverURL,
            modelName: model,
            apiKey: apiKey,
            maxRetries: maxRetries
        ))
        let agent = try RetryingLLMChatAgent(configuration: config)
        let result = try await agent.run(goal: goal)
        print(result)
    }
}
