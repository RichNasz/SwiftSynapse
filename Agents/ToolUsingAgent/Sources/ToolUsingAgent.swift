// Generated strictly from Agents/ToolUsingAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseHarness

public enum ToolUsingAgentError: Error, Sendable {
    case emptyGoal
    case noResponseContent
    case toolCallFailed(String)
    case unknownTool(String)
    case toolLoopExceeded
}

// MARK: - Tool Definitions

/// Evaluates a basic arithmetic expression and returns the result as a Double.
@LLMTool
public struct Calculate: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "A math expression using +, -, *, /. Example: '144 / 12'")
        var expression: String
    }

    public static var isConcurrencySafe: Bool { true }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        let sanitized = arguments.expression.filter { "0123456789.+-*/() ".contains($0) }
        guard !sanitized.isEmpty else {
            throw ToolUsingAgentError.toolCallFailed("calculate")
        }
        let expr = NSExpression(format: sanitized)
        guard let result = expr.expressionValue(with: nil, context: nil) as? NSNumber else {
            throw ToolUsingAgentError.toolCallFailed("calculate")
        }
        return ToolOutput(content: "\(result.doubleValue)")
    }
}

/// Converts a value from one unit to another. Supports length, weight, and temperature.
@LLMTool
public struct ConvertUnit: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "The numeric value to convert.")
        var value: Double
        @LLMToolGuide(description: "Source unit. One of: meters, feet, miles, kilometers, kilograms, pounds, celsius, fahrenheit.")
        var fromUnit: String
        @LLMToolGuide(description: "Target unit. Same options as fromUnit.")
        var toUnit: String
    }

    public static var isConcurrencySafe: Bool { true }

    private static let conversionToBase: [String: (factor: Double, dimension: String)] = [
        "meters": (1.0, "length"),
        "feet": (0.3048, "length"),
        "miles": (1609.344, "length"),
        "kilometers": (1000.0, "length"),
        "kilograms": (1.0, "weight"),
        "pounds": (0.453592, "weight"),
    ]

    public func call(arguments: Arguments) async throws -> ToolOutput {
        if arguments.fromUnit == "celsius" && arguments.toUnit == "fahrenheit" {
            let result = arguments.value * 9.0 / 5.0 + 32.0
            return ToolOutput(content: String(format: "%.4f", result))
        }
        if arguments.fromUnit == "fahrenheit" && arguments.toUnit == "celsius" {
            let result = (arguments.value - 32.0) * 5.0 / 9.0
            return ToolOutput(content: String(format: "%.4f", result))
        }
        if (arguments.fromUnit == "celsius" || arguments.fromUnit == "fahrenheit") &&
           (arguments.toUnit == "celsius" || arguments.toUnit == "fahrenheit") &&
           arguments.fromUnit == arguments.toUnit {
            return ToolOutput(content: String(format: "%.4f", arguments.value))
        }
        guard let from = Self.conversionToBase[arguments.fromUnit] else {
            throw ToolUsingAgentError.toolCallFailed("convert_unit")
        }
        guard let to = Self.conversionToBase[arguments.toUnit] else {
            throw ToolUsingAgentError.toolCallFailed("convert_unit")
        }
        guard from.dimension == to.dimension else {
            throw ToolUsingAgentError.toolCallFailed("convert_unit")
        }
        let baseValue = arguments.value * from.factor
        let result = baseValue / to.factor
        return ToolOutput(content: String(format: "%.4f", result))
    }
}

/// Formats a number with a specified number of decimal places.
@LLMTool
public struct FormatNumber: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "The number to format.")
        var value: Double
        @LLMToolGuide(description: "Number of decimal places. 0–10.", .range(0...10))
        var decimalPlaces: Int
    }

    public static var isConcurrencySafe: Bool { true }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        let clamped = min(max(arguments.decimalPlaces, 0), 10)
        return ToolOutput(content: String(format: "%.\(clamped)f", arguments.value))
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

    public func execute(goal: String) async throws -> String {
        guard !goal.isEmpty else {
            _status = .error(ToolUsingAgentError.emptyGoal)
            throw ToolUsingAgentError.emptyGoal
        }

        let client = try config.buildClient()

        let tools = ToolRegistry()
        tools.register(Calculate())
        tools.register(ConvertUnit())
        tools.register(FormatNumber())

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
