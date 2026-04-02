// Generated strictly from Agents/DataPipelineAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseHarness

public enum DataPipelineAgentError: Error, Sendable {
    case noResponseContent
    case dataFileNotFound(String)
}

// MARK: - Tool Definitions (AgentToolProtocol)

/// Reads a CSV file and returns its contents as a JSON array of row objects.
public struct ReadCSVTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let filePath: String
    }
    public typealias Output = String

    public static let name = "readCSV"
    public static let description = "Reads a CSV file and returns its contents as a JSON array of row objects."
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("filePath", .string(description: "Path to the CSV file to read."))
                ],
                required: ["filePath"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        // Mock CSV data representing a sample dataset
        let mockData: [[String: Any]] = [
            ["name": "Alice", "age": 30, "department": "Engineering", "salary": 95000],
            ["name": "Bob", "age": 25, "department": "Marketing", "salary": 72000],
            ["name": "Charlie", "age": 35, "department": "Engineering", "salary": 110000],
            ["name": "Diana", "age": 28, "department": "Sales", "salary": 68000],
            ["name": "Eve", "age": 32, "department": "Engineering", "salary": 102000]
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: mockData, options: [.sortedKeys])
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw DataPipelineAgentError.noResponseContent
        }
        return jsonString
    }
}

/// Filters a JSON array of objects by a column value matching a predicate.
public struct FilterCSVTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let data: String
        public let column: String
        public let predicate: String
    }
    public typealias Output = String

    public static let name = "filterCSV"
    public static let description = "Filters a JSON array of objects by a column value matching a predicate string."
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("data", .string(description: "JSON array of row objects to filter.")),
                    ("column", .string(description: "Column name to filter on.")),
                    ("predicate", .string(description: "Value to match against the column."))
                ],
                required: ["data", "column", "predicate"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        guard let data = input.data.data(using: .utf8),
              let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return "[]"
        }
        let filtered = array.filter { row in
            guard let value = row[input.column] else { return false }
            return "\(value)" == input.predicate
        }
        let resultData = try JSONSerialization.data(withJSONObject: filtered, options: [.sortedKeys])
        return String(data: resultData, encoding: .utf8) ?? "[]"
    }
}

/// Aggregates a numeric column in a JSON array using sum, avg, count, min, or max.
public struct AggregateCSVTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let data: String
        public let column: String
        public let operation: String
    }
    public typealias Output = String

    public static let name = "aggregateCSV"
    public static let description = "Aggregates a numeric column in a JSON array using sum, avg, count, min, or max."
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("data", .string(description: "JSON array of row objects.")),
                    ("column", .string(description: "Numeric column name to aggregate.")),
                    ("operation", .string(description: "Aggregation operation: sum, avg, count, min, or max."))
                ],
                required: ["data", "column", "operation"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        guard let data = input.data.data(using: .utf8),
              let array = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return "0"
        }
        let values: [Double] = array.compactMap { row in
            guard let val = row[input.column] else { return nil }
            if let num = val as? NSNumber {
                return num.doubleValue
            }
            return Double("\(val)")
        }
        guard !values.isEmpty else { return "0" }

        let result: Double
        switch input.operation.lowercased() {
        case "sum":
            result = values.reduce(0, +)
        case "avg":
            result = values.reduce(0, +) / Double(values.count)
        case "count":
            result = Double(values.count)
        case "min":
            result = values.min() ?? 0
        case "max":
            result = values.max() ?? 0
        default:
            result = 0
        }
        // Format without trailing zeros for clean output
        if result == result.rounded() && result < 1e15 {
            return String(format: "%.0f", result)
        }
        return String(format: "%.4f", result)
    }
}

/// Extracts a value from a JSON object using a dot-separated key path.
public struct QueryJSONTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let data: String
        public let path: String
    }
    public typealias Output = String

    public static let name = "queryJSON"
    public static let description = "Extracts a value from a JSON object or array using a dot-separated key path."
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("data", .string(description: "JSON string to query.")),
                    ("path", .string(description: "Dot-separated key path (e.g. 'users.0.name')."))
                ],
                required: ["data", "path"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        guard let data = input.data.data(using: .utf8),
              let root = try JSONSerialization.jsonObject(with: data) as? Any else {
            return "null"
        }
        let components = input.path.split(separator: ".").map(String.init)
        var current: Any = root
        for component in components {
            if let dict = current as? [String: Any], let next = dict[component] {
                current = next
            } else if let arr = current as? [Any], let index = Int(component), index >= 0, index < arr.count {
                current = arr[index]
            } else {
                return "null"
            }
        }
        if let str = current as? String {
            return str
        }
        if let num = current as? NSNumber {
            return "\(num)"
        }
        if JSONSerialization.isValidJSONObject(current) {
            let jsonData = try JSONSerialization.data(withJSONObject: current, options: [.sortedKeys])
            return String(data: jsonData, encoding: .utf8) ?? "null"
        }
        return "\(current)"
    }
}

/// Generates a formatted Markdown report from a title and JSON array of sections.
public struct GenerateReportTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let title: String
        public let sections: String
    }
    public typealias Output = String

    public static let name = "generateReport"
    public static let description = "Generates a formatted Markdown report from a title and JSON array of sections."
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("title", .string(description: "Report title.")),
                    ("sections", .string(description: "JSON array of section objects with 'heading' and 'body' keys."))
                ],
                required: ["title", "sections"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        var markdown = "# \(input.title)\n\n"
        if let data = input.sections.data(using: .utf8),
           let sectionArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            for section in sectionArray {
                let heading = section["heading"] as? String ?? "Untitled"
                let body = section["body"] as? String ?? ""
                markdown += "## \(heading)\n\n\(body)\n\n"
            }
        } else {
            markdown += input.sections + "\n"
        }
        return markdown
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

    /// Legacy convenience init for backward compatibility.
    public init(serverURL: String, modelName: String, apiKey: String? = nil, maxRetries: Int = 3) throws {
        let config = try AgentConfiguration(serverURL: serverURL, modelName: modelName, apiKey: apiKey, maxRetries: maxRetries)
        try self.init(configuration: config)
    }

    public func execute(goal: String) async throws -> String {
        let client = try config.buildClient()

        let tools = ToolRegistry()
        tools.register(ReadCSVTool())
        tools.register(FilterCSVTool())
        tools.register(AggregateCSVTool())
        tools.register(QueryJSONTool())
        tools.register(GenerateReportTool())

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
