// Generated strictly from Agents/LLMChatPersonas/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import ArgumentParser
import LLMChatPersonasAgent

@main
struct LLMChatPersonasCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "llm-chat-personas",
        abstract: "Send a prompt to an Open Responses API endpoint and optionally rewrite the reply in a persona's voice."
    )

    @Argument(help: "The prompt to send to the LLM.")
    var goal: String

    @Option(name: .long, help: "Full URL of an Open Responses API endpoint (e.g. http://127.0.0.1:1234/v1/responses).")
    var serverURL: String

    @Option(name: .long, help: "Model identifier (e.g. llama3, gpt-4o).")
    var model: String

    @Option(name: .long, help: "Optional API key for authentication.")
    var apiKey: String?

    @Option(name: .long, help: "Optional persona for rewriting the response (e.g. pirate, James Kirk).")
    var persona: String?

    func run() async throws {
        let agent = try LLMChatPersonas(serverURL: serverURL, modelName: model, apiKey: apiKey)
        let result = try await agent.run(goal: goal, persona: persona)

        if let persona, let initial = await agent.lastInitialResponse {
            print("--- Original Response ---")
            print(initial)
            print()
            print("--- \(persona) Response ---")
        }
        print(result)
    }
}
