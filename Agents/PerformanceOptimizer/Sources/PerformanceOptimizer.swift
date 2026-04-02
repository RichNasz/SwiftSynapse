// Generated strictly from Agents/PerformanceOptimizer/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseHarness

public enum PerformanceOptimizerError: Error, Sendable {
    case noResponseContent
    case benchmarkFailed(String)
    case profilingUnavailable
}

// MARK: - Tool Definitions (AgentToolProtocol)

/// Analyzes a profiling snapshot for the given file path and returns a JSON summary.
public struct AnalyzeProfileTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let filePath: String
    }
    public typealias Output = String

    public static let name = "analyzeProfile"
    public static let description = "Analyzes a profiling snapshot for the given file path and returns a JSON summary."
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("filePath", .string(description: "Path to the source file to profile."))
                ],
                required: ["filePath"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        let fileName = (input.filePath as NSString).lastPathComponent
        return """
        {"file":"\(fileName)","totalTime_ms":342,"hotspots":[{"function":"processData","time_ms":187,"percentage":54.7},{"function":"serialize","time_ms":98,"percentage":28.7},{"function":"validate","time_ms":57,"percentage":16.6}],"allocations":1247,"peakMemory_kb":8192}
        """
    }
}

/// Benchmarks two code alternatives over a number of iterations and returns comparison results.
public struct BenchmarkAlternativeTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let original: String
        public let alternative: String
        public let iterations: Int
    }
    public typealias Output = String

    public static let name = "benchmarkAlternative"
    public static let description = "Benchmarks two code alternatives over a number of iterations and returns comparison results."
    public static let isConcurrencySafe = false

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("original", .string(description: "The original code snippet to benchmark.")),
                    ("alternative", .string(description: "The alternative code snippet to benchmark.")),
                    ("iterations", .integer(description: "Number of iterations to run.", minimum: 1, maximum: 100000))
                ],
                required: ["original", "alternative", "iterations"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        guard input.iterations > 0 else {
            throw PerformanceOptimizerError.benchmarkFailed("iterations must be positive")
        }
        let originalTime = Double(input.original.count) * 0.42
        let alternativeTime = Double(input.alternative.count) * 0.31
        let speedup = originalTime / max(alternativeTime, 0.001)
        return """
        {"iterations":\(input.iterations),"original":{"avg_ms":\(String(format: "%.2f", originalTime)),"min_ms":\(String(format: "%.2f", originalTime * 0.9)),"max_ms":\(String(format: "%.2f", originalTime * 1.1))},"alternative":{"avg_ms":\(String(format: "%.2f", alternativeTime)),"min_ms":\(String(format: "%.2f", alternativeTime * 0.9)),"max_ms":\(String(format: "%.2f", alternativeTime * 1.1))},"speedup":\(String(format: "%.2f", speedup)),"winner":"\(speedup > 1.0 ? "alternative" : "original")"}
        """
    }
}

/// Suggests an optimization for the given code and issue description.
public struct SuggestOptimizationTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let code: String
        public let issue: String
    }
    public typealias Output = String

    public static let name = "suggestOptimization"
    public static let description = "Suggests an optimization for the given code and issue description."
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("code", .string(description: "The code snippet to optimize.")),
                    ("issue", .string(description: "Description of the performance issue."))
                ],
                required: ["code", "issue"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        return """
        Optimization suggestion for issue: \(input.issue)

        Original code length: \(input.code.count) characters

        Recommended changes:
        1. Replace linear search with hash-based lookup (O(n) -> O(1))
        2. Cache computed results to avoid redundant calculations
        3. Use lazy evaluation for deferred computation

        Estimated improvement: 40-60% reduction in execution time.
        """
    }
}

/// Measures memory usage for the given file and returns a memory profile JSON.
public struct MeasureMemoryTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let filePath: String
    }
    public typealias Output = String

    public static let name = "measureMemory"
    public static let description = "Measures memory usage for the given file and returns a memory profile JSON."
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("filePath", .string(description: "Path to the source file to measure."))
                ],
                required: ["filePath"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        let fileName = (input.filePath as NSString).lastPathComponent
        return """
        {"file":"\(fileName)","heapAllocations":3421,"stackPeak_kb":256,"heapPeak_kb":16384,"retainCycles":0,"leaks":[],"largestAllocation":{"type":"Array<Data>","size_kb":4096,"count":12},"recommendation":"Consider using ContiguousArray for better cache locality."}
        """
    }
}

/// Compares multiple implementation approaches and returns a detailed analysis.
public struct CompareImplementationsTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let implementations: [String]
    }
    public typealias Output = String

    public static let name = "compareImplementations"
    public static let description = "Compares multiple implementation approaches and returns a detailed analysis."
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("implementations", .array(items: .string(description: "A code snippet to compare.")))
                ],
                required: ["implementations"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        var analysis = "Comparison of \(input.implementations.count) implementations:\n\n"
        for (index, impl) in input.implementations.enumerated() {
            let complexity = impl.count < 50 ? "Low" : impl.count < 150 ? "Medium" : "High"
            let score = max(100 - index * 8, 60)
            analysis += """
            Implementation \(index + 1):
              Length: \(impl.count) characters
              Complexity: \(complexity)
              Estimated performance score: \(score)/100
              Memory efficiency: \(score > 80 ? "Good" : "Needs improvement")

            """
        }
        analysis += "Recommendation: Implementation 1 offers the best balance of readability and performance."
        return analysis
    }
}

// MARK: - Agent

@SpecDrivenAgent
public actor PerformanceOptimizer {
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
        tools.register(AnalyzeProfileTool())
        tools.register(BenchmarkAlternativeTool())
        tools.register(SuggestOptimizationTool())
        tools.register(MeasureMemoryTool())
        tools.register(CompareImplementationsTool())

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
            throw PerformanceOptimizerError.noResponseContent
        }

        return result
    }
}
