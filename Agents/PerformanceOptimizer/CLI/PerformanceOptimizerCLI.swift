// Generated strictly from Agents/PerformanceOptimizer/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import ArgumentParser
import PerformanceOptimizerAgent
import SwiftSynapseHarness

@main
struct PerformanceOptimizerCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "performance-optimizer",
        abstract: "Analyze code performance and suggest optimizations using an LLM with profiling tools."
    )

    @Argument(help: "A natural-language performance analysis or optimization request.")
    var goal: String

    @Option(name: .long, help: "Full URL of an Open Responses API endpoint. Falls back to SWIFTSYNAPSE_SERVER_URL env var.")
    var serverURL: String?

    @Option(name: .long, help: "Model identifier (e.g. llama3, gpt-4o). Falls back to SWIFTSYNAPSE_MODEL env var.")
    var model: String?

    @Option(name: .long, help: "Optional API key for authentication. Falls back to SWIFTSYNAPSE_API_KEY env var.")
    var apiKey: String?

    @Option(name: .long, help: "Optional file path to target for profiling or analysis.")
    var file: String?

    @Flag(name: .long, help: "Enable verbose logging of agent events via hooks.")
    var verbose = false

    func run() async throws {
        let config = try AgentConfiguration.fromEnvironment(overrides: .init(
            serverURL: serverURL,
            modelName: model,
            apiKey: apiKey
        ))
        let agent = try PerformanceOptimizer(configuration: config)

        // Hook demo: verbose logging of agent lifecycle and tool events
        if verbose {
            let pipeline = AgentHookPipeline()
            await pipeline.add(ClosureHook(
                on: [
                    .llmRequestSent, .llmResponseReceived,
                    .preToolUse, .postToolUse,
                    .transcriptUpdated
                ]
            ) { event in
                switch event {
                case .llmRequestSent:
                    print("[hook] Sending LLM request...")
                case .llmResponseReceived(let response):
                    let toolCount = response.toolCalls.count
                    if toolCount > 0 {
                        let names = response.toolCalls.map(\.name).joined(separator: ", ")
                        print("[hook] LLM responded with \(toolCount) tool call(s): \(names)")
                    } else {
                        print("[hook] LLM responded with final text")
                    }
                case .preToolUse(let calls):
                    for call in calls {
                        print("[hook] Executing tool: \(call.name)")
                    }
                case .postToolUse(let results):
                    for result in results {
                        let status = result.success ? "OK" : "FAILED"
                        print("[hook] Tool \(result.name) completed [\(status)] in \(result.duration)")
                    }
                default:
                    break
                }
                return .proceed
            })
            await agent.setHooks(pipeline)
        }

        // If a file path was provided, prepend it to the goal for context
        let effectiveGoal: String
        if let file = file {
            effectiveGoal = "File: \(file). \(goal)"
        } else {
            effectiveGoal = goal
        }

        let result = try await agent.run(goal: effectiveGoal)
        print(result)
    }
}
