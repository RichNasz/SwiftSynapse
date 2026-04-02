// Generated strictly from Agents/PRReviewer/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import ArgumentParser
import PRReviewerAgent
import SwiftSynapseHarness

@main
struct PRReviewerCLI: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "pr-reviewer",
        abstract: "Analyze code diffs for Swift style, security, and quality issues with safety guardrails."
    )

    @Argument(help: "A natural-language review request (e.g. 'Review PR #42 for style and security issues').")
    var goal: String

    @Option(name: .long, help: "Full URL of an Open Responses API endpoint. Falls back to SWIFTSYNAPSE_SERVER_URL env var.")
    var serverURL: String?

    @Option(name: .long, help: "Model identifier (e.g. llama3, gpt-4o). Falls back to SWIFTSYNAPSE_MODEL env var.")
    var model: String?

    @Option(name: .long, help: "Optional API key for authentication. Falls back to SWIFTSYNAPSE_API_KEY env var.")
    var apiKey: String?

    @Option(name: .long, help: "Path to a local .diff or .patch file to review.")
    var diffPath: String?

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
        let agent = try PRReviewer(configuration: config)

        // Hook demo: verbose logging of agent lifecycle and tool events
        if verbose {
            let pipeline = AgentHookPipeline()
            await pipeline.add(ClosureHook(
                on: [
                    .llmRequestSent, .llmResponseReceived,
                    .preToolUse, .postToolUse,
                    .transcriptUpdated, .guardrailTriggered
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
                case .guardrailTriggered(let info):
                    print("[hook] Guardrail triggered: \(info)")
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
                .requireApproval(["fetchDiff", "suggestPatch"])
            ])
            let gate = PermissionGate()
            await gate.addPolicy(policy)
            await gate.setApprovalDelegate(CLIApprovalDelegate())
            await agent.setPermissionGate(gate)
        }

        // Guardrail demo: always set up content filtering for safety
        let guardrails = GuardrailPipeline()
        await guardrails.add(ContentFilter.default)
        await agent.setGuardrailPipeline(guardrails)

        // Build goal with optional diff path context
        var fullGoal = goal
        if let diffPath = diffPath {
            fullGoal += " (diff file: \(diffPath))"
        }

        let result = try await agent.run(goal: fullGoal)
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
