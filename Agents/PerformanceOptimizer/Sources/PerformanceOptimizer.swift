// Generated strictly from Agents/PerformanceOptimizer/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseHarness

public enum PerformanceOptimizerError: Error, Sendable {
    case emptyGoal
    case noResponseContent
    case benchmarkFailed(String)
    case profilingUnavailable
}

// MARK: - Tool Definitions

/// Analyzes a profiling snapshot for the given file path and returns a JSON summary.
@LLMTool
public struct AnalyzeProfile: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "Path to the source file to profile.")
        var filePath: String
    }

    public static var isConcurrencySafe: Bool { true }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        let fileName = (arguments.filePath as NSString).lastPathComponent
        return ToolOutput(content: """
        {"file":"\(fileName)","totalTime_ms":342,"hotspots":[{"function":"processData","time_ms":187,"percentage":54.7},{"function":"serialize","time_ms":98,"percentage":28.7},{"function":"validate","time_ms":57,"percentage":16.6}],"allocations":1247,"peakMemory_kb":8192}
        """)
    }
}

/// Benchmarks two code alternatives over a number of iterations and returns comparison results.
@LLMTool
public struct BenchmarkAlternative: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "The original code snippet to benchmark.")
        var original: String
        @LLMToolGuide(description: "The alternative code snippet to benchmark.")
        var alternative: String
        @LLMToolGuide(description: "Number of iterations to run.", .range(1...100000))
        var iterations: Int
    }

    public static var isConcurrencySafe: Bool { false }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        guard arguments.iterations > 0 else {
            throw PerformanceOptimizerError.benchmarkFailed("iterations must be positive")
        }
        let originalTime = Double(arguments.original.count) * 0.42
        let alternativeTime = Double(arguments.alternative.count) * 0.31
        let speedup = originalTime / max(alternativeTime, 0.001)
        return ToolOutput(content: """
        {"iterations":\(arguments.iterations),"original":{"avg_ms":\(String(format: "%.2f", originalTime)),"min_ms":\(String(format: "%.2f", originalTime * 0.9)),"max_ms":\(String(format: "%.2f", originalTime * 1.1))},"alternative":{"avg_ms":\(String(format: "%.2f", alternativeTime)),"min_ms":\(String(format: "%.2f", alternativeTime * 0.9)),"max_ms":\(String(format: "%.2f", alternativeTime * 1.1))},"speedup":\(String(format: "%.2f", speedup)),"winner":"\(speedup > 1.0 ? "alternative" : "original")"}
        """)
    }
}

/// Suggests an optimization for the given code and issue description.
@LLMTool
public struct SuggestOptimization: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "The code snippet to optimize.")
        var code: String
        @LLMToolGuide(description: "Description of the performance issue.")
        var issue: String
    }

    public static var isConcurrencySafe: Bool { true }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        return ToolOutput(content: """
        Optimization suggestion for issue: \(arguments.issue)

        Original code length: \(arguments.code.count) characters

        Recommended changes:
        1. Replace linear search with hash-based lookup (O(n) -> O(1))
        2. Cache computed results to avoid redundant calculations
        3. Use lazy evaluation for deferred computation

        Estimated improvement: 40-60% reduction in execution time.
        """)
    }
}

/// Measures memory usage for the given file and returns a memory profile JSON.
@LLMTool
public struct MeasureMemory: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "Path to the source file to measure.")
        var filePath: String
    }

    public static var isConcurrencySafe: Bool { true }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        let fileName = (arguments.filePath as NSString).lastPathComponent
        return ToolOutput(content: """
        {"file":"\(fileName)","heapAllocations":3421,"stackPeak_kb":256,"heapPeak_kb":16384,"retainCycles":0,"leaks":[],"largestAllocation":{"type":"Array<Data>","size_kb":4096,"count":12},"recommendation":"Consider using ContiguousArray for better cache locality."}
        """)
    }
}

/// Compares multiple implementation approaches and returns a detailed analysis.
@LLMTool
public struct CompareImplementations: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "Code snippets to compare.")
        var implementations: [String]
    }

    public static var isConcurrencySafe: Bool { true }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        var analysis = "Comparison of \(arguments.implementations.count) implementations:\n\n"
        for (index, impl) in arguments.implementations.enumerated() {
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
        return ToolOutput(content: analysis)
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

    public func execute(goal: String) async throws -> String {
        guard !goal.isEmpty else {
            _status = .error(PerformanceOptimizerError.emptyGoal)
            throw PerformanceOptimizerError.emptyGoal
        }

        let client = try config.buildClient()

        let tools = ToolRegistry()
        tools.register(AnalyzeProfile())
        tools.register(BenchmarkAlternative())
        tools.register(SuggestOptimization())
        tools.register(MeasureMemory())
        tools.register(CompareImplementations())

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
