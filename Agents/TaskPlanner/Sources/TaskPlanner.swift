// Generated strictly from Agents/TaskPlanner/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseHarness

public enum TaskPlannerError: Error, Sendable {
    case noResponseContent
    case phaseDecompositionFailed
    case synthesisFailedNoResults
}

// MARK: - Tool Definitions (AgentToolProtocol)

/// Breaks a complex goal into phases with dependency information.
public struct BreakdownGoalTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let goal: String
    }
    public typealias Output = String

    public static let name = "breakdownGoal"
    public static let description = "Breaks a complex goal into phases with dependencies. Returns a JSON array of phases."
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("goal", .string(description: "The complex goal to decompose into phases with dependencies."))
                ],
                required: ["goal"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        // Returns the goal wrapped in a JSON response suggesting the LLM should break it down
        let phases: [[String: Any]] = [
            [
                "id": "phase-1",
                "name": "Research & Analysis",
                "description": "Research and analyze: \(input.goal)",
                "dependencies": [] as [String]
            ],
            [
                "id": "phase-2",
                "name": "Planning & Design",
                "description": "Create a detailed plan based on research findings.",
                "dependencies": ["phase-1"]
            ],
            [
                "id": "phase-3",
                "name": "Execution & Delivery",
                "description": "Execute the plan and deliver results.",
                "dependencies": ["phase-2"]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: phases, options: [.sortedKeys])
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

/// Assigns priority scores to phases and determines execution order.
public struct PrioritizeTasksTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let phases: String
    }
    public typealias Output = String

    public static let name = "prioritizeTasks"
    public static let description = "Prioritizes phases by adding priority scores and determining execution order."
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("phases", .string(description: "JSON array of phases to prioritize."))
                ],
                required: ["phases"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        // Parses phases JSON array and adds priority scores
        guard let data = input.phases.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return #"{"error":"Invalid phases JSON","prioritized":[]}"#
        }

        var prioritized: [[String: Any]] = []
        for (index, phase) in parsed.enumerated() {
            var updated = phase
            let priority = max(100 - (index * 10), 10)
            updated["priority"] = priority
            updated["executionOrder"] = index + 1
            prioritized.append(updated)
        }

        let result: [String: Any] = [
            "prioritized": prioritized,
            "totalPhases": prioritized.count
        ]
        let resultData = try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys])
        return String(data: resultData, encoding: .utf8) ?? #"{"prioritized":[]}"#
    }
}

/// Synthesizes phase results into a unified Markdown plan.
public struct SynthesizeResultsTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let phaseResults: String
    }
    public typealias Output = String

    public static let name = "synthesizeResults"
    public static let description = "Combines phase results into a unified Markdown plan document."
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("phaseResults", .string(description: "JSON map of phase ID to result content."))
                ],
                required: ["phaseResults"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        // Formats the phase results into a structured Markdown document with sections
        guard let data = input.phaseResults.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return "# Plan\n\nNo results available."
        }

        var markdown = "# Unified Plan\n\n"
        markdown += "## Overview\n\n"
        markdown += "This plan synthesizes results from \(parsed.count) phase(s).\n\n"

        let sortedKeys = parsed.keys.sorted()
        for key in sortedKeys {
            let value = parsed[key]
            markdown += "## \(key)\n\n"
            if let stringValue = value as? String {
                markdown += "\(stringValue)\n\n"
            } else {
                markdown += "Result: \(String(describing: value))\n\n"
            }
        }

        markdown += "---\n\n*Plan generated by TaskPlanner agent.*\n"
        return markdown
    }
}

// MARK: - Agent

@SpecDrivenAgent
public actor TaskPlanner {
    private let config: AgentConfiguration
    /// Optional hook pipeline for event interception.
    public private(set) var hooks: AgentHookPipeline?

    /// Sets the hook pipeline for event interception.
    public func setHooks(_ hooks: AgentHookPipeline) { self.hooks = hooks }

    private static let maxToolIterations = 10

    public init(configuration: AgentConfiguration) throws {
        self.config = configuration
    }

    /// Legacy convenience init for backward compatibility.
    public init(serverURL: String, modelName: String, apiKey: String? = nil, maxRetries: Int = 3) throws {
        let config = try AgentConfiguration(serverURL: serverURL, modelName: modelName, apiKey: apiKey, maxRetries: maxRetries)
        try self.init(configuration: config)
    }

    public func execute(goal: String) async throws -> String {
        let client = try config.buildClient()

        let tools = ToolRegistry()
        tools.register(BreakdownGoalTool())
        tools.register(PrioritizeTasksTool())
        tools.register(SynthesizeResultsTool())

        let systemPrompt = "You are a task planning coordinator. Break complex goals into phases with dependencies, prioritize them, and synthesize results into a unified plan."

        let result = try await AgentToolLoop.run(
            client: client,
            config: config,
            goal: goal,
            tools: tools,
            transcript: _transcript,
            systemPrompt: systemPrompt,
            maxIterations: Self.maxToolIterations,
            hooks: hooks
        )

        guard !result.isEmpty else {
            throw TaskPlannerError.noResponseContent
        }

        return result
    }
}
