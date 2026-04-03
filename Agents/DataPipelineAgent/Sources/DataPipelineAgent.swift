// Generated strictly from Agents/DataPipelineAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseHarness

public enum DataPipelineAgentError: Error, Sendable {
    case noResponseContent
    case dataFileNotFound(String)
}

// MARK: - Tool Definitions

/// Reads a CSV file and returns its contents as a JSON array of row objects.
@LLMTool
public struct ReadCSV: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "Path to the CSV file to read.")
        var filePath: String
    }

    public static var isConcurrencySafe: Bool { true }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        let mockData: [[String: Any]] = [
            ["name": "Alice",   "age": 30, "department": "Engineering", "salary": 95000],
            ["name": "Bob",     "age": 25, "department": "Marketing",   "salary": 72000],
            ["name": "Charlie", "age": 35, "department": "Engineering", "salary": 110000],
            ["name": "Diana",   "age": 28, "department": "Sales",       "salary": 68000],
            ["name": "Eve",     "age": 32, "department": "Engineering", "salary": 102000]
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: mockData, options: [.sortedKeys])
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw DataPipelineAgentError.noResponseContent
        }
        return ToolOutput(content: jsonString)
    }
}

/// Filters a JSON array of objects by a column value matching a predicate string.
@LLMTool
public struct FilterCSV: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "JSON array of row objects to filter.")
        var data: String
        @LLMToolGuide(description: "Column name to filter on.")
        var column: String
        @LLMToolGuide(description: "Value to match against the column.")
        var predicate: String
    }

    public static var isConcurrencySafe: Bool { true }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        guard let data = arguments.data.data(using: .utf8),
              let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return ToolOutput(content: "[]")
        }
        let filtered = array.filter { row in
            guard let value = row[arguments.column] else { return false }
            return "\(value)" == arguments.predicate
        }
        let resultData = try JSONSerialization.data(withJSONObject: filtered, options: [.sortedKeys])
        return ToolOutput(content: String(data: resultData, encoding: .utf8) ?? "[]")
    }
}

/// Aggregates a numeric column in a JSON array using sum, avg, count, min, or max.
@LLMTool
public struct AggregateCSV: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "JSON array of row objects.")
        var data: String
        @LLMToolGuide(description: "Numeric column name to aggregate.")
        var column: String
        @LLMToolGuide(description: "Aggregation operation.", .anyOf(["sum", "avg", "count", "min", "max"]))
        var operation: String
    }

    public static var isConcurrencySafe: Bool { true }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        guard let data = arguments.data.data(using: .utf8),
              let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return ToolOutput(content: "0")
        }
        let values: [Double] = array.compactMap { row in
            guard let val = row[arguments.column] else { return nil }
            if let num = val as? NSNumber { return num.doubleValue }
            return Double("\(val)")
        }
        guard !values.isEmpty else { return ToolOutput(content: "0") }

        let result: Double
        switch arguments.operation.lowercased() {
        case "sum":   result = values.reduce(0, +)
        case "avg":   result = values.reduce(0, +) / Double(values.count)
        case "count": result = Double(values.count)
        case "min":   result = values.min() ?? 0
        case "max":   result = values.max() ?? 0
        default:      result = 0
        }

        if result == result.rounded() && result < 1e15 {
            return ToolOutput(content: String(format: "%.0f", result))
        }
        return ToolOutput(content: String(format: "%.4f", result))
    }
}

/// Extracts a value from a JSON object or array using a dot-separated key path.
@LLMTool
public struct QueryJSON: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "JSON string to query.")
        var data: String
        @LLMToolGuide(description: "Dot-separated key path (e.g. 'users.0.name').")
        var path: String
    }

    public static var isConcurrencySafe: Bool { true }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        guard let data = arguments.data.data(using: .utf8) else {
            return ToolOutput(content: "null")
        }
        let root = try JSONSerialization.jsonObject(with: data)
        let components = arguments.path.split(separator: ".").map(String.init)
        var current: Any = root
        for component in components {
            if let dict = current as? [String: Any], let next = dict[component] {
                current = next
            } else if let arr = current as? [Any], let index = Int(component), index >= 0, index < arr.count {
                current = arr[index]
            } else {
                return ToolOutput(content: "null")
            }
        }
        if let str = current as? String { return ToolOutput(content: str) }
        if let num = current as? NSNumber { return ToolOutput(content: "\(num)") }
        if JSONSerialization.isValidJSONObject(current) {
            let jsonData = try JSONSerialization.data(withJSONObject: current, options: [.sortedKeys])
            return ToolOutput(content: String(data: jsonData, encoding: .utf8) ?? "null")
        }
        return ToolOutput(content: "\(current)")
    }
}

/// Generates a formatted Markdown report from a title and JSON array of sections.
@LLMTool
public struct GeneratePipelineReport: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "Report title.")
        var title: String
        @LLMToolGuide(description: "JSON array of section objects with 'heading' and 'body' keys.")
        var sections: String
    }

    public static var isConcurrencySafe: Bool { true }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        var markdown = "# \(arguments.title)\n\n"
        if let data = arguments.sections.data(using: .utf8),
           let sectionArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for section in sectionArray {
                let heading = section["heading"] as? String ?? "Untitled"
                let body = section["body"] as? String ?? ""
                markdown += "## \(heading)\n\n\(body)\n\n"
            }
        } else {
            markdown += arguments.sections + "\n"
        }
        return ToolOutput(content: markdown)
    }
}

// MARK: - Agent

@SpecDrivenAgent
public actor DataPipelineAgent {
    private let config: AgentConfiguration
    /// Optional hook pipeline for event interception.
    public private(set) var hooks: AgentHookPipeline?

    /// Sets the hook pipeline for event interception.
    public func setHooks(_ hooks: AgentHookPipeline) { self.hooks = hooks }

    private static let maxToolIterations = 10

    public init(configuration: AgentConfiguration) throws {
        self.config = configuration
    }

    public func execute(goal: String) async throws -> String {
        let client = try config.buildClient()

        let tools = ToolRegistry()
        tools.register(ReadCSV())
        tools.register(FilterCSV())
        tools.register(AggregateCSV())
        tools.register(QueryJSON())
        tools.register(GeneratePipelineReport())

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
            throw DataPipelineAgentError.noResponseContent
        }

        return result
    }
}
