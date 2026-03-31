// Generated strictly from Agents/ToolUsingAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseMacrosClient

public enum ToolUsingAgentError: Error, Sendable {
    case emptyGoal
    case invalidServerURL
    case noResponseContent
    case toolCallFailed(String)
    case unknownTool(String)
    case toolLoopExceeded
}

@SpecDrivenAgent
public actor ToolUsingAgent {
    private let modelName: String
    private let maxRetries: Int
    private let _llmClient: LLMClient

    private static let maxToolIterations = 10

    public init(serverURL: String, modelName: String, apiKey: String? = nil, maxRetries: Int = 3) throws {
        guard !serverURL.isEmpty,
              let parsedURL = URL(string: serverURL),
              parsedURL.scheme == "http" || parsedURL.scheme == "https" else {
            throw ToolUsingAgentError.invalidServerURL
        }
        self.modelName = modelName
        self.maxRetries = maxRetries
        self._llmClient = try LLMClient(baseURL: serverURL, apiKey: apiKey ?? "")
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

        var request = try ResponseRequest(model: modelName) {
            try RequestTimeout(300)
            try ResourceTimeout(300)
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
                response = try await retryWithBackoff(maxAttempts: maxRetries) {
                    try await self._llmClient.send(currentRequest)
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

            var toolOutputs: [InputItem] = []

            for call in functionCalls {
                _transcript.append(.toolCall(name: call.name, arguments: call.arguments))

                let start = ContinuousClock.now
                let result: String
                do {
                    result = try dispatchTool(name: call.name, arguments: call.arguments)
                } catch {
                    let duration = ContinuousClock.now - start
                    _transcript.append(.toolResult(name: call.name, result: "Error: \(error)", duration: duration))
                    _status = .error(error)
                    throw error
                }
                let duration = ContinuousClock.now - start
                _transcript.append(.toolResult(name: call.name, result: result, duration: duration))
                toolOutputs.append(FunctionOutput(callId: call.callId, output: result))
            }

            let previousId = response.id
            request = try ResponseRequest(
                model: modelName,
                config: {
                    try RequestTimeout(300)
                    try ResourceTimeout(300)
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

    private func dispatchTool(name: String, arguments: String) throws -> String {
        let data = Data(arguments.utf8)
        switch name {
        case "calculate":
            return try Self.calculate(data: data)
        case "convertUnit":
            return try Self.convertUnit(data: data)
        case "formatNumber":
            return try Self.formatNumber(data: data)
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

    // MARK: - Retry

    private func retryWithBackoff<T: Sendable>(
        maxAttempts: Int,
        baseDelay: Duration = .milliseconds(500),
        operation: @Sendable () async throws -> T
    ) async throws -> T {
        var lastError: Error?
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                guard isRetryable(error), attempt < maxAttempts else {
                    if attempt >= maxAttempts {
                        break
                    }
                    throw error
                }
                let nextAttempt = attempt + 1
                _transcript.append(.reasoning(
                    ReasoningItem(
                        id: "retry-\(nextAttempt)",
                        summary: [ReasoningSummary(type: "summary_text", text: "Retrying LLM call (attempt \(nextAttempt) of \(maxAttempts))\u{2026}")]
                    )
                ))
                let delayNs = UInt64(baseDelay.components.attoseconds / 1_000_000_000) * UInt64(1 << (attempt - 1))
                try await Task.sleep(nanoseconds: delayNs)
            }
        }
        throw lastError!
    }

    private func isRetryable(_ error: Error) -> Bool {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet:
                return true
            default:
                return false
            }
        }
        return false
    }
}
