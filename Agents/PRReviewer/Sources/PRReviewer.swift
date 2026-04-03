// Generated strictly from Agents/PRReviewer/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseHarness

public enum PRReviewerError: Error, Sendable {
    case emptyGoal
    case noResponseContent
    case diffTooLarge(path: String)
}

// MARK: - Tool Definitions

/// Fetches a unified diff from a local file path or simulated PR number.
@LLMTool
public struct FetchDiff: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "A local file path to a .diff/.patch file, or a PR number (e.g. '42').")
        var source: String
    }

    public static var isConcurrencySafe: Bool { true }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        if arguments.source.contains("/") || arguments.source.hasSuffix(".diff") || arguments.source.hasSuffix(".patch") {
            let url = URL(fileURLWithPath: arguments.source)
            if let data = try? Data(contentsOf: url), let content = String(data: data, encoding: .utf8) {
                return ToolOutput(content: content)
            }
        }
        return ToolOutput(content: """
        --- a/App.swift
        +++ b/App.swift
        @@ -5,3 +5,5 @@
             let apiKey = "sk-test123"
        -    let x = opt!
        +    guard let x = opt else { return }
        +    func helper() { }
        """)
    }
}

/// Analyzes Swift code for common style issues: force unwraps, long lines, and missing access control.
@LLMTool
public struct AnalyzeSwiftStyle: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "The Swift source code to analyze for style issues.")
        var code: String
    }

    public static var isConcurrencySafe: Bool { true }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        var issues: [[String: String]] = []
        let lines = arguments.code.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if !trimmed.hasPrefix("//") && line.contains("!") {
                let forceUnwrapPattern = try? NSRegularExpression(pattern: #"\w+!"#)
                let range = NSRange(line.startIndex..., in: line)
                if let _ = forceUnwrapPattern?.firstMatch(in: line, range: range) {
                    issues.append([
                        "line": "\(lineNumber)",
                        "severity": "warning",
                        "message": "Force unwrap detected. Consider using optional binding or nil coalescing."
                    ])
                }
            }

            if line.count > 120 {
                issues.append([
                    "line": "\(lineNumber)",
                    "severity": "warning",
                    "message": "Line exceeds 120 characters (\(line.count) chars). Consider breaking into multiple lines."
                ])
            }

            if (trimmed.hasPrefix("func ") || trimmed.hasPrefix("class ") || trimmed.hasPrefix("struct "))
                && !trimmed.hasPrefix("public ") && !trimmed.hasPrefix("private ")
                && !trimmed.hasPrefix("internal ") && !trimmed.hasPrefix("fileprivate ")
                && !trimmed.hasPrefix("open ") {
                issues.append([
                    "line": "\(lineNumber)",
                    "severity": "info",
                    "message": "Missing explicit access control modifier. Consider adding public/private/internal."
                ])
            }
        }

        let data = try JSONSerialization.data(withJSONObject: issues, options: [.sortedKeys])
        return ToolOutput(content: String(data: data, encoding: .utf8) ?? "[]")
    }
}

/// Checks Swift code for security anti-patterns: hardcoded credentials, API keys, and force unwraps in security-critical paths.
@LLMTool
public struct CheckSecurityPatterns: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "The Swift source code to scan for security issues.")
        var code: String
    }

    public static var isConcurrencySafe: Bool { true }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        var findings: [[String: String]] = []
        let lines = arguments.code.components(separatedBy: "\n")

        let securityPatterns: [(pattern: String, risk: String, message: String)] = [
            (#"(password|passwd|pwd)\s*[:=]"#, "high", "Hardcoded password."),
            (#"(api[_-]?key|apikey)\s*[:=]"#, "high", "Hardcoded API key."),
            (#"(secret|token)\s*[:=]\s*\""#, "high", "Hardcoded secret/token."),
            (#"sk-[a-zA-Z0-9]{10,}"#, "critical", "OpenAI API key in source."),
            (#"ghp_[a-zA-Z0-9]{30,}"#, "critical", "GitHub token in source."),
        ]

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("//") { continue }

            for (pattern, risk, message) in securityPatterns {
                let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSRange(line.startIndex..., in: line)
                if let _ = regex?.firstMatch(in: line, range: range) {
                    findings.append(["line": "\(lineNumber)", "risk": risk, "pattern": pattern, "message": message])
                }
            }
        }

        let data = try JSONSerialization.data(withJSONObject: findings, options: [.sortedKeys])
        return ToolOutput(content: String(data: data, encoding: .utf8) ?? "[]")
    }
}

/// Generates a formatted patch suggestion for a specific code issue.
@LLMTool
public struct SuggestPatch: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "The file path where the issue was found.")
        var file: String
        @LLMToolGuide(description: "Description of the issue to fix.")
        var issue: String
        @LLMToolGuide(description: "The suggested code change.")
        var suggestion: String
    }

    public static var isConcurrencySafe: Bool { true }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        return ToolOutput(content: """
        --- Patch Suggestion ---
        File: \(arguments.file)
        Issue: \(arguments.issue)

        Suggested Change:
        ```swift
        \(arguments.suggestion)
        ```
        """)
    }
}

/// Formats review findings and patch suggestions into a structured Markdown report.
@LLMTool
public struct FormatReview: AgentLLMTool {
    @LLMToolArguments
    public struct Arguments {
        @LLMToolGuide(description: "JSON string of findings from analysis and security checks.")
        var findings: String
        @LLMToolGuide(description: "JSON string or text of suggested patches.")
        var patches: String
    }

    public static var isConcurrencySafe: Bool { true }

    public func call(arguments: Arguments) async throws -> ToolOutput {
        return ToolOutput(content: """
        ## Code Review Summary

        ### Findings

        \(arguments.findings)

        ### Suggested Patches

        \(arguments.patches)

        ---
        *Generated by PRReviewer Agent*
        """)
    }
}

// MARK: - Agent

@SpecDrivenAgent
public actor PRReviewer {
    private let config: AgentConfiguration
    /// Optional hook pipeline for event interception.
    public private(set) var hooks: AgentHookPipeline?
    /// Optional permission gate for tool access control.
    public private(set) var permissionGate: PermissionGate?
    /// Optional guardrail pipeline for content safety.
    public private(set) var guardrailPipeline: GuardrailPipeline?

    /// Sets the hook pipeline for event interception.
    public func setHooks(_ hooks: AgentHookPipeline) { self.hooks = hooks }
    /// Sets the permission gate for tool access control.
    public func setPermissionGate(_ gate: PermissionGate) { self.permissionGate = gate }
    /// Sets the guardrail pipeline for content safety.
    public func setGuardrailPipeline(_ pipeline: GuardrailPipeline) { self.guardrailPipeline = pipeline }

    private static let maxToolIterations = 6

    public init(configuration: AgentConfiguration) throws {
        self.config = configuration
    }

    public func execute(goal: String) async throws -> String {
        guard !goal.isEmpty else {
            _status = .error(PRReviewerError.emptyGoal)
            throw PRReviewerError.emptyGoal
        }

        let client = try config.buildClient()

        let tools = ToolRegistry()
        tools.register(FetchDiff())
        tools.register(AnalyzeSwiftStyle())
        tools.register(CheckSecurityPatterns())
        tools.register(SuggestPatch())
        tools.register(FormatReview())

        if let gate = permissionGate {
            tools.permissionGate = gate
        }

        let systemPrompt = """
        You are a Swift code reviewer. Analyze code for style and security issues.
        Use the available tools to fetch diffs, analyze style, and check security.
        After gathering findings, respond with a brief Markdown summary.
        Do NOT call tools more than 3 times total. Produce your final answer as plain text.
        """

        let result = try await AgentToolLoop.run(
            client: client,
            config: config,
            goal: goal,
            tools: tools,
            transcript: _transcript,
            systemPrompt: systemPrompt,
            maxIterations: Self.maxToolIterations,
            hooks: hooks,
            guardrails: guardrailPipeline
        )

        guard !result.isEmpty else {
            throw PRReviewerError.noResponseContent
        }

        return result
    }
}
