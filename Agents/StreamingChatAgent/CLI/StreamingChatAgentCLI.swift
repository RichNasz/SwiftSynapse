// Generated strictly from Agents/StreamingChatAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import ArgumentParser
import StreamingChatAgentAgent

@main
struct StreamingChatAgentCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "streaming-chat-agent",
        abstract: "Stream a prompt response from an Open Responses API endpoint token-by-token."
    )

    @Argument(help: "The prompt to send to the LLM.")
    var goal: String

    @Option(name: .long, help: "Full URL of an Open Responses API endpoint (e.g. http://127.0.0.1:1234/v1/responses).")
    var serverURL: String

    @Option(name: .long, help: "Model identifier (e.g. llama3, gpt-4o).")
    var model: String

    @Option(name: .long, help: "Optional API key for authentication.")
    var apiKey: String?

    func run() async throws {
        let agent = try StreamingChatAgent(serverURL: serverURL, modelName: model, apiKey: apiKey)
        let result = try await agent.execute(goal: goal)
        print(result)
    }
}
