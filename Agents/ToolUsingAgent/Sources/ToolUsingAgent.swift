// Generated strictly from Agents/ToolUsingAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseHarness

public enum ToolUsingAgentError: Error, Sendable {
    case noResponseContent
    case toolCallFailed(String)
    case unknownTool(String)
    case toolLoopExceeded
}

// MARK: - Tool Definitions (AgentToolProtocol)

/// Evaluates a basic arithmetic expression and returns the result as a Double.
public struct CalculateTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let expression: String
    }
    public typealias Output = String

    public static let name = "calculate"
    public static let description = "Evaluates a basic arithmetic expression and returns the result as a Double."
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("expression", .string(description: "A math expression using +, -, *, /. Example: '144 / 12'"))
                ],
                required: ["expression"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        let sanitized = input.expression.filter { "0123456789.+-*/() ".contains($0) }
        guard !sanitized.isEmpty else {
            throw ToolUsingAgentError.toolCallFailed("calculate")
        }
        let expr = NSExpression(format: sanitized)
        guard let result = expr.expressionValue(with: nil, context: nil) as? NSNumber else {
            throw ToolUsingAgentError.toolCallFailed("calculate")
        }
        return "\(result.doubleValue)"
    }
}

/// Converts a value from one unit to another. Supports length, weight, and temperature.
public struct ConvertUnitTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let value: Double
        public let fromUnit: String
        public let toUnit: String
    }
    public typealias Output = String

    public static let name = "convertUnit"
    public static let description = "Converts a value from one unit to another. Supports length, weight, and temperature."
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("value", .number(description: "The numeric value to convert.", minimum: nil, maximum: nil)),
                    ("fromUnit", .string(description: "Source unit. One of: meters, feet, miles, kilometers, kilograms, pounds, celsius, fahrenheit.")),
                    ("toUnit", .string(description: "Target unit. Same options as fromUnit."))
                ],
                required: ["value", "fromUnit", "toUnit"]
            ),
            strict: true
        )
    }

    private static let conversionToBase: [String: (factor: Double, dimension: String)] = [
        "meters": (1.0, "length"),
        "feet": (0.3048, "length"),
        "miles": (1609.344, "length"),
        "kilometers": (1000.0, "length"),
        "kilograms": (1.0, "weight"),
        "pounds": (0.453592, "weight"),
    ]

    public func execute(input: Input) async throws -> String {
        // Temperature is a special case
        if input.fromUnit == "celsius" && input.toUnit == "fahrenheit" {
            let result = input.value * 9.0 / 5.0 + 32.0
            return String(format: "%.4f", result)
        }
        if input.fromUnit == "fahrenheit" && input.toUnit == "celsius" {
            let result = (input.value - 32.0) * 5.0 / 9.0
            return String(format: "%.4f", result)
        }
        if (input.fromUnit == "celsius" || input.fromUnit == "fahrenheit") &&
           (input.toUnit == "celsius" || input.toUnit == "fahrenheit") &&
           input.fromUnit == input.toUnit {
            return String(format: "%.4f", input.value)
        }

        guard let from = Self.conversionToBase[input.fromUnit] else {
            throw ToolUsingAgentError.toolCallFailed("convertUnit")
        }
        guard let to = Self.conversionToBase[input.toUnit] else {
            throw ToolUsingAgentError.toolCallFailed("convertUnit")
        }
        guard from.dimension == to.dimension else {
            throw ToolUsingAgentError.toolCallFailed("convertUnit")
        }

        let baseValue = input.value * from.factor
        let result = baseValue / to.factor
        return String(format: "%.4f", result)
    }
}

/// Formats a number with a specified number of decimal places.
public struct FormatNumberTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let value: Double
        public let decimalPlaces: Int
    }
    public typealias Output = String

    public static let name = "formatNumber"
    public static let description = "Formats a number with a specified number of decimal places."
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("value", .number(description: "The number to format.", minimum: nil, maximum: nil)),
                    ("decimalPlaces", .integer(description: "Number of decimal places. 0\u{2013}10.", minimum: 0, maximum: 10))
                ],
                required: ["value", "decimalPlaces"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        let clamped = min(max(input.decimalPlaces, 0), 10)
        return String(format: "%.\(clamped)f", input.value)
    }
}

// MARK: - Agent

@SpecDrivenAgent
public actor ToolUsingAgent {
    private let config: AgentConfiguration
    /// Optional hook pipeline for event interception.
    public private(set) var hooks: AgentHookPipeline?
    /// Optional permission gate for tool access control.
    public private(set) var permissionGate: PermissionGate?

    /// Sets the hook pipeline for event interception.
    public func setHooks(_ hooks: AgentHookPipeline) { self.hooks = hooks }
    /// Sets the permission gate for tool access control.
    public func setPermissionGate(_ gate: PermissionGate) { self.permissionGate = gate }

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
        tools.register(CalculateTool())
        tools.register(ConvertUnitTool())
        tools.register(FormatNumberTool())

        if let gate = permissionGate {
            tools.permissionGate = gate
        }

        let result = try await AgentToolLoop.run(
            client: client,
            config: config,
            goal: goal,
            tools: tools,
            transcript: _transcript,
            maxIterations: Self.maxToolIterations,
            hooks: hooks
        )

        guard !result.isEmpty else {
            throw ToolUsingAgentError.noResponseContent
        }

        return result
    }
}
