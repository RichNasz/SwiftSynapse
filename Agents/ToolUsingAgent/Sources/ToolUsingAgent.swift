// Generated strictly from Agents/ToolUsingAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseMacrosClient

public enum ToolUsingAgentError: Error, Sendable {
    case emptyGoal
    case noResponseContent
    case toolCallFailed(String)
    case unknownTool(String)
    case toolLoopExceeded
}

@SpecDrivenAgent
public actor ToolUsingAgent {
    private let config: AgentConfiguration

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
        guard !goal.isEmpty else {
            _status = .error(ToolUsingAgentError.emptyGoal)
            throw ToolUsingAgentError.emptyGoal
        }

        _status = .running
        _transcript.reset()

        let client = try config.buildLLMClient()
        let toolDefs = Self.toolDefinitions()
        let agent = try Agent(
            client: client,
            model: config.modelName,
            maxToolIterations: Self.maxToolIterations
        ) {
            AgentTool(tool: toolDefs[0]) { args in try Self.dispatchTool(name: "calculate", arguments: args) }
            AgentTool(tool: toolDefs[1]) { args in try Self.dispatchTool(name: "convertUnit", arguments: args) }
            AgentTool(tool: toolDefs[2]) { args in try Self.dispatchTool(name: "formatNumber", arguments: args) }
        }

        let result: String
        do {
            result = try await retryWithBackoff(maxAttempts: config.maxRetries) {
                await agent.reset()
                return try await agent.send(goal)
            }
        } catch {
            _status = .error(error)
            throw error
        }

        guard !result.isEmpty else {
            _status = .error(ToolUsingAgentError.noResponseContent)
            throw ToolUsingAgentError.noResponseContent
        }

        _transcript.sync(from: await agent.transcript)
        _status = .completed(result)
        return result
    }

    // MARK: - Tool Definitions

    private static func toolDefinitions() -> [FunctionToolParam] {
        [
            FunctionToolParam(
                name: "calculate",
                description: "Evaluates a basic arithmetic expression and returns the result as a Double.",
                parameters: .object(
                    properties: [
                        ("expression", .string(description: "A math expression using +, -, *, /. Example: '144 / 12'"))
                    ],
                    required: ["expression"]
                ),
                strict: true
            ),
            FunctionToolParam(
                name: "convertUnit",
                description: "Converts a value from one unit to another. Supports length, weight, and temperature.",
                parameters: .object(
                    properties: [
                        ("value", .number(description: "The numeric value to convert.", minimum: nil, maximum: nil)),
                        ("fromUnit", .string(description: "Source unit. One of: meters, feet, miles, kilometers, kilograms, pounds, celsius, fahrenheit.")),
                        ("toUnit", .string(description: "Target unit. Same options as fromUnit."))
                    ],
                    required: ["value", "fromUnit", "toUnit"]
                ),
                strict: true
            ),
            FunctionToolParam(
                name: "formatNumber",
                description: "Formats a number with a specified number of decimal places.",
                parameters: .object(
                    properties: [
                        ("value", .number(description: "The number to format.", minimum: nil, maximum: nil)),
                        ("decimalPlaces", .integer(description: "Number of decimal places. 0\u{2013}10.", minimum: 0, maximum: 10))
                    ],
                    required: ["value", "decimalPlaces"]
                ),
                strict: true
            ),
        ]
    }

    // MARK: - Tool Dispatch

    private static func dispatchTool(name: String, arguments: String) throws -> String {
        let data = Data(arguments.utf8)
        switch name {
        case "calculate":
            return try calculate(data: data)
        case "convertUnit":
            return try convertUnit(data: data)
        case "formatNumber":
            return try formatNumber(data: data)
        default:
            throw ToolUsingAgentError.unknownTool(name)
        }
    }

    // MARK: - Tool Implementations

    private struct CalculateArgs: Codable, Sendable {
        let expression: String
    }

    static func calculate(data: Data) throws -> String {
        let args = try JSONDecoder().decode(CalculateArgs.self, from: data)
        let sanitized = args.expression.filter { "0123456789.+-*/() ".contains($0) }
        guard !sanitized.isEmpty else {
            throw ToolUsingAgentError.toolCallFailed("calculate")
        }
        let expr = NSExpression(format: sanitized)
        guard let result = expr.expressionValue(with: nil, context: nil) as? NSNumber else {
            throw ToolUsingAgentError.toolCallFailed("calculate")
        }
        return "\(result.doubleValue)"
    }

    private struct ConvertUnitArgs: Codable, Sendable {
        let value: Double
        let fromUnit: String
        let toUnit: String
    }

    private static let conversionToBase: [String: (factor: Double, dimension: String)] = [
        "meters": (1.0, "length"),
        "feet": (0.3048, "length"),
        "miles": (1609.344, "length"),
        "kilometers": (1000.0, "length"),
        "kilograms": (1.0, "weight"),
        "pounds": (0.453592, "weight"),
    ]

    static func convertUnit(data: Data) throws -> String {
        let args = try JSONDecoder().decode(ConvertUnitArgs.self, from: data)

        // Temperature is a special case
        if args.fromUnit == "celsius" && args.toUnit == "fahrenheit" {
            let result = args.value * 9.0 / 5.0 + 32.0
            return String(format: "%.4f", result)
        }
        if args.fromUnit == "fahrenheit" && args.toUnit == "celsius" {
            let result = (args.value - 32.0) * 5.0 / 9.0
            return String(format: "%.4f", result)
        }
        if (args.fromUnit == "celsius" || args.fromUnit == "fahrenheit") &&
           (args.toUnit == "celsius" || args.toUnit == "fahrenheit") &&
           args.fromUnit == args.toUnit {
            return String(format: "%.4f", args.value)
        }

        guard let from = conversionToBase[args.fromUnit] else {
            throw ToolUsingAgentError.toolCallFailed("convertUnit")
        }
        guard let to = conversionToBase[args.toUnit] else {
            throw ToolUsingAgentError.toolCallFailed("convertUnit")
        }
        guard from.dimension == to.dimension else {
            throw ToolUsingAgentError.toolCallFailed("convertUnit")
        }

        let baseValue = args.value * from.factor
        let result = baseValue / to.factor
        return String(format: "%.4f", result)
    }

    private struct FormatNumberArgs: Codable, Sendable {
        let value: Double
        let decimalPlaces: Int
    }

    static func formatNumber(data: Data) throws -> String {
        let args = try JSONDecoder().decode(FormatNumberArgs.self, from: data)
        let clamped = min(max(args.decimalPlaces, 0), 10)
        return String(format: "%.\(clamped)f", args.value)
    }
}
