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
    private let _llmClient: LLMClient

    private static let maxToolIterations = 10

    public init(configuration: AgentConfiguration) throws {
        self.config = configuration
        self._llmClient = try configuration.buildLLMClient()
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
        _transcript.append(.userMessage(goal))

        let toolDefs = Self.toolDefinitions()
        let timeout = TimeInterval(config.timeoutSeconds)

        var request = try ResponseRequest(model: config.modelName) {
            try RequestTimeout(timeout)
            try ResourceTimeout(timeout)
        } input: {
            User(goal)
        }
        request.tools = toolDefs

        var iteration = 0
        while iteration <= Self.maxToolIterations {
            try Task.checkCancellation()

            let response: ResponseObject
            do {
                let currentRequest = request
                let capturedClient = _llmClient
                response = try await retryWithBackoff(maxAttempts: config.maxRetries) {
                    try await capturedClient.send(currentRequest)
                }
            } catch {
                _status = .error(error)
                throw error
            }

            guard response.requiresToolExecution,
                  let functionCalls = response.firstFunctionCalls else {
                let responseText = response.firstOutputText ?? ""
                guard !responseText.isEmpty else {
                    _status = .error(ToolUsingAgentError.noResponseContent)
                    throw ToolUsingAgentError.noResponseContent
                }
                _transcript.append(.assistantMessage(responseText))
                _status = .completed(responseText)
                return responseText
            }

            iteration += 1
            guard iteration <= Self.maxToolIterations else {
                _status = .error(ToolUsingAgentError.toolLoopExceeded)
                throw ToolUsingAgentError.toolLoopExceeded
            }

            // Log all tool calls
            for call in functionCalls {
                _transcript.append(.toolCall(name: call.name, arguments: call.arguments))
            }

            // Execute via ToolExecutor (all tools are concurrency-safe pure functions)
            let toolCalls = functionCalls.enumerated().map { (i, call) in
                ToolExecutor.ToolCall(name: call.name, arguments: call.arguments, index: i)
            }
            let executor = ToolExecutor()
            let results: [ToolExecutor.ToolResult]
            do {
                results = try await executor.execute(calls: toolCalls) { name, arguments in
                    try Self.dispatchTool(name: name, arguments: arguments)
                }
            } catch {
                _status = .error(error)
                throw error
            }

            // Log results and build outputs
            var toolOutputs: [InputItem] = []
            for result in results {
                _transcript.append(.toolResult(name: result.name, result: result.result, duration: result.duration))
                toolOutputs.append(FunctionOutput(callId: functionCalls[result.index].callId, output: result.result))
            }

            let previousId = response.id
            request = try ResponseRequest(
                model: config.modelName,
                config: {
                    try RequestTimeout(timeout)
                    try ResourceTimeout(timeout)
                    try PreviousResponseId(previousId)
                },
                input: toolOutputs
            )
            request.tools = toolDefs
        }

        _status = .error(ToolUsingAgentError.toolLoopExceeded)
        throw ToolUsingAgentError.toolLoopExceeded
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
