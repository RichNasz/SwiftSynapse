// Generated strictly from Agents/ResearchAssistant/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseHarness

public enum ResearchAssistantError: Error, Sendable {
    case noResponseContent
    case sessionCorrupted
}

// MARK: - Tool Definitions (AgentToolProtocol)

/// Searches the web for a given query and returns a JSON array of search results.
public struct SearchWebTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let query: String
        public let maxResults: Int
    }
    public typealias Output = String

    public static let name = "searchWeb"
    public static let description = "Searches the web for a given query and returns a JSON array of search results."
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("query", .string(description: "The search query string.")),
                    ("maxResults", .integer(description: "Maximum number of results to return.", minimum: 1, maximum: 20))
                ],
                required: ["query", "maxResults"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        let clamped = min(max(input.maxResults, 1), 20)
        var results: [[String: String]] = []
        for i in 1...clamped {
            results.append([
                "title": "Result \(i) for '\(input.query)'",
                "url": "https://example.com/result/\(i)",
                "snippet": "This is a summary of result \(i) related to '\(input.query)'."
            ])
        }
        let data = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

/// Reads the content of a document at a given URL and returns extracted text.
public struct ReadDocumentTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let url: String
    }
    public typealias Output = String

    public static let name = "readDocument"
    public static let description = "Reads the content of a document at a given URL and returns extracted text."
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("url", .string(description: "The URL of the document to read."))
                ],
                required: ["url"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        return """
        [Document content extracted from \(input.url)]

        This is the full text content of the document. It contains detailed information \
        relevant to the research query. The document discusses key findings, methodologies, \
        and conclusions that can be cited in the final report.
        """
    }
}

/// Saves a piece of information to long-term memory with a category and tags.
public struct SaveMemoryTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let content: String
        public let category: String
        public let tags: [String]
    }
    public typealias Output = String

    public static let name = "saveMemory"
    public static let description = "Saves a piece of information to long-term memory with a category and tags."
    public static let isConcurrencySafe = false

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("content", .string(description: "The information to save.")),
                    ("category", .string(description: "Category label (e.g. 'finding', 'source', 'note').")),
                    ("tags", .array(items: .string(description: "A tag string.")))
                ],
                required: ["content", "category", "tags"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        let memoryId = UUID().uuidString
        return "Memory saved. ID: \(memoryId), category: \(input.category), tags: \(input.tags.joined(separator: ", "))"
    }
}

/// Recalls memories matching a query and returns a JSON array of memory entries.
public struct RecallMemoryTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let query: String
    }
    public typealias Output = String

    public static let name = "recallMemory"
    public static let description = "Recalls memories matching a query and returns a JSON array of memory entries."
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("query", .string(description: "The recall query to search saved memories."))
                ],
                required: ["query"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        let entries: [[String: Any]] = [
            [
                "id": UUID().uuidString,
                "content": "Previously saved finding related to '\(input.query)'.",
                "category": "finding",
                "tags": ["research", input.query.lowercased()],
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ],
            [
                "id": UUID().uuidString,
                "content": "A relevant source document about '\(input.query)' was reviewed.",
                "category": "source",
                "tags": ["source", input.query.lowercased()],
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys])
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

/// Saves a session checkpoint and returns a session ID for later resumption.
public struct SaveCheckpointTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {}
    public typealias Output = String

    public static let name = "saveCheckpoint"
    public static let description = "Saves a session checkpoint and returns a session ID for later resumption."
    public static let isConcurrencySafe = false

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [],
                required: []
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        let sessionId = UUID().uuidString
        return "Checkpoint saved. Session ID: \(sessionId)"
    }
}

/// Generates a Markdown report from a topic and findings.
public struct GenerateReportTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let topic: String
        public let findings: String
    }
    public typealias Output = String

    public static let name = "generateReport"
    public static let description = "Generates a Markdown report from a topic and findings."
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("topic", .string(description: "The research topic.")),
                    ("findings", .string(description: "The collected findings to include in the report."))
                ],
                required: ["topic", "findings"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        return """
        # Research Report: \(input.topic)

        ## Summary

        This report presents the findings of a research investigation into \(input.topic).

        ## Findings

        \(input.findings)

        ## Conclusion

        The research on \(input.topic) has yielded the above findings. Further investigation \
        may be warranted to expand upon these results.

        ---
        *Report generated automatically by ResearchAssistant.*
        """
    }
}

// MARK: - Agent

@SpecDrivenAgent
public actor ResearchAssistant {
    private let config: AgentConfiguration
    /// Optional hook pipeline for event interception.
    public private(set) var hooks: AgentHookPipeline?

    /// Sets the hook pipeline for event interception.
    public func setHooks(_ hooks: AgentHookPipeline) { self.hooks = hooks }

    private static let maxToolIterations = 15

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
        tools.register(SearchWebTool())
        tools.register(ReadDocumentTool())
        tools.register(SaveMemoryTool())
        tools.register(RecallMemoryTool())
        tools.register(SaveCheckpointTool())
        tools.register(GenerateReportTool())

        let systemPrompt = "You are a research assistant. Use tools to search, read documents, save findings to memory, and generate reports."

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
            throw ResearchAssistantError.noResponseContent
        }

        return result
    }
}
