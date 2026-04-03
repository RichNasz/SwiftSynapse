// Generated strictly from Agents/ResearchAssistant/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseHarness

public enum ResearchAssistantError: Error, Sendable {
    case emptyGoal
    case noResponseContent
    case sessionTypeMismatch(expected: String, actual: String)
    case sessionCorrupted
    case mcpConnectionFailed(server: String, error: any Error)
}

// MARK: - Tool Definitions

/// Searches the web for a given query and returns a JSON array of search results.
@LLMTool
public struct SearchWeb: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "The search query string.")
        var query: String
        @LLMToolGuide(description: "Maximum number of results to return.", .range(1...20))
        var maxResults: Int
    }

    public static var isConcurrencySafe: Bool { true }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        let clamped = min(max(arguments.maxResults, 1), 20)
        var results: [[String: String]] = []
        for i in 1...clamped {
            results.append([
                "title": "Result \(i) for '\(arguments.query)'",
                "url": "https://example.com/result/\(i)",
                "snippet": "This is a summary of result \(i) related to '\(arguments.query)'."
            ])
        }
        let data = try JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys])
        return ToolOutput(content: String(data: data, encoding: .utf8) ?? "[]")
    }
}

/// Reads the content of a document at a given URL and returns extracted text.
@LLMTool
public struct ReadDocument: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "The URL of the document to read.")
        var url: String
    }

    public static var isConcurrencySafe: Bool { true }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        return ToolOutput(content: """
        [Document content extracted from \(arguments.url)]

        This is the full text content of the document. It contains detailed information \
        relevant to the research query. The document discusses key findings, methodologies, \
        and conclusions that can be cited in the final report.
        """)
    }
}

/// Saves a piece of information to long-term memory with a category and tags.
@LLMTool
public struct SaveMemory: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "The information to save.")
        var content: String
        @LLMToolGuide(description: "Category label (e.g. 'finding', 'source', 'note').")
        var category: String
        @LLMToolGuide(description: "Tag strings for this memory entry.")
        var tags: [String]
    }

    public static var isConcurrencySafe: Bool { false }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        let memoryId = UUID().uuidString
        return ToolOutput(content: "Memory saved. ID: \(memoryId), category: \(arguments.category), tags: \(arguments.tags.joined(separator: ", "))")
    }
}

/// Recalls memories matching a query and returns a JSON array of memory entries.
@LLMTool
public struct RecallMemory: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "The recall query to search saved memories.")
        var query: String
    }

    public static var isConcurrencySafe: Bool { true }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        let entries: [[String: Any]] = [
            [
                "id": UUID().uuidString,
                "content": "Previously saved finding related to '\(arguments.query)'.",
                "category": "finding",
                "tags": ["research", arguments.query.lowercased()],
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ],
            [
                "id": UUID().uuidString,
                "content": "A relevant source document about '\(arguments.query)' was reviewed.",
                "category": "source",
                "tags": ["source", arguments.query.lowercased()],
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: entries, options: [.prettyPrinted, .sortedKeys])
        return ToolOutput(content: String(data: data, encoding: .utf8) ?? "[]")
    }
}

/// Saves a session checkpoint and returns a session ID for later resumption.
@LLMTool
public struct SaveCheckpoint: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {}

    public static var isConcurrencySafe: Bool { false }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        return ToolOutput(content: "Checkpoint saved. Session ID: \(UUID().uuidString)")
    }
}

/// Generates a Markdown report from a topic and findings.
@LLMTool
public struct GenerateResearchReport: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "The research topic.")
        var topic: String
        @LLMToolGuide(description: "The collected findings to include in the report.")
        var findings: String
    }

    public static var isConcurrencySafe: Bool { true }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        return ToolOutput(content: """
        # Research Report: \(arguments.topic)

        ## Summary

        This report presents the findings of a research investigation into \(arguments.topic).

        ## Findings

        \(arguments.findings)

        ## Conclusion

        The research on \(arguments.topic) has yielded the above findings. Further investigation \
        may be warranted to expand upon these results.

        ---
        *Report generated automatically by ResearchAssistant.*
        """)
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

    public func execute(goal: String) async throws -> String {
        guard !goal.isEmpty else {
            _status = .error(ResearchAssistantError.emptyGoal)
            throw ResearchAssistantError.emptyGoal
        }

        let client = try config.buildClient()

        let tools = ToolRegistry()
        tools.register(SearchWeb())
        tools.register(ReadDocument())
        tools.register(SaveMemory())
        tools.register(RecallMemory())
        tools.register(SaveCheckpoint())
        tools.register(GenerateResearchReport())

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
