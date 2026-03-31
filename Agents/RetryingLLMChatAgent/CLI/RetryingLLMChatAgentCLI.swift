// Generated strictly from Agents/RetryingLLMChatAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import ArgumentParser
import RetryingLLMChatAgentAgent

@main
struct RetryingLLMChatAgentCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "retrying-llm-chat-agent",
        abstract: "Send a prompt to an Open Responses API endpoint with automatic retry on transient failures."
    )

    @Argument(help: "The prompt to send to the LLM.")
    var goal: String

    @Option(name: .long, help: "Full URL of an Open Responses API endpoint (e.g. http://127.0.0.1:1234/v1/responses).")
    var serverURL: String

    @Option(name: .long, help: "Model identifier (e.g. llama3, gpt-4o).")
    var model: String

    @Option(name: .long, help: "Optional API key for authentication.")
    var apiKey: String?

    @Option(name: .long, help: "Maximum number of retry attempts (1–10, default 3).")
    var maxRetries: Int = 3

    func run() async throws {
        let agent = try RetryingLLMChatAgent(serverURL: serverURL, modelName: model, apiKey: apiKey, maxRetries: maxRetries)
        let result = try await agent.execute(goal: goal)
        print(result)
    }
}
