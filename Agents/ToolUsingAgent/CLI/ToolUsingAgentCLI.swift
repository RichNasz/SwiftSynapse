// Generated strictly from Agents/ToolUsingAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import ArgumentParser
import ToolUsingAgentAgent
import SwiftSynapseHarness

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

    @Flag(name: .long, help: "Enable verbose logging of agent events via hooks.")
    var verbose = false

    @Flag(name: .long, help: "Require approval before each tool execution (demonstrates permission system).")
    var requireApproval = false

    func run() async throws {
        let config = try AgentConfiguration.fromEnvironment(overrides: .init(
            serverURL: serverURL,
            modelName: model,
            apiKey: apiKey
        ))
        let agent = try ToolUsingAgent(configuration: config)

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

        // Permission demo: require interactive approval for tool use
        if requireApproval {
            let policy = ToolListPolicy(rules: [
                .requireApproval(["calculate", "convertUnit", "formatNumber"])
            ])
            let gate = PermissionGate()
            await gate.addPolicy(policy)
            await gate.setApprovalDelegate(CLIApprovalDelegate())
            await agent.setPermissionGate(gate)
        }

        let result = try await agent.run(goal: goal)
        print(result)
    }
}

/// Simple CLI approval delegate that prompts on stdin.
struct CLIApprovalDelegate: ApprovalDelegate {
    func requestApproval(toolName: String, arguments: String, reason: String) async -> Bool {
        print("[permission] Tool '\(toolName)' requires approval: \(reason)")
        print("[permission] Arguments: \(arguments)")
        print("[permission] Allow? (y/n): ", terminator: "")
        guard let line = readLine()?.lowercased() else { return false }
        return line == "y" || line == "yes"
    }
}
