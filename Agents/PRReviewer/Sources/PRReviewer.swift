// Generated strictly from Agents/PRReviewer/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseHarness

public enum PRReviewerError: Error, Sendable {
    case noResponseContent
    case diffTooLarge(String)
}

// MARK: - Tool Definitions (AgentToolProtocol)

/// Fetches a unified diff from a local file path or simulated PR number.
public struct FetchDiffTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let source: String
    }
    public typealias Output = String

    public static let name = "fetchDiff"
    public static let description = "Fetches a unified diff from a local file path or PR number."
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("source", .string(description: "A local file path to a .diff/.patch file, or a PR number (e.g. '42')."))
                ],
                required: ["source"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        // If source looks like a file path, attempt to read it
        if input.source.contains("/") || input.source.hasSuffix(".diff") || input.source.hasSuffix(".patch") {
            let url = URL(fileURLWithPath: input.source)
            if let data = try? Data(contentsOf: url), let content = String(data: data, encoding: .utf8) {
                return content
            }
        }

        // Simulated diff for demonstration
        return """
        --- a/App.swift
        +++ b/App.swift
        @@ -5,3 +5,5 @@
             let apiKey = "sk-test123"
        -    let x = opt!
        +    guard let x = opt else { return }
        +    func helper() { }
        """
    }
}

/// Analyzes Swift code for common style issues using pattern matching.
public struct AnalyzeSwiftStyleTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let code: String
    }
    public typealias Output = String

    public static let name = "analyzeSwiftStyle"
    public static let description = "Analyzes Swift code for common style issues (force unwraps, long lines, missing access control)."
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("code", .string(description: "The Swift source code to analyze for style issues."))
                ],
                required: ["code"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        var issues: [[String: String]] = []
        let lines = input.code.components(separatedBy: "\n")

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Detect force unwraps (but not in comments)
            if !trimmed.hasPrefix("//") && line.contains("!") {
                // Check for force unwrap pattern: identifier followed by !
                // Exclude boolean negation and string interpolation
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

            // Detect long lines (over 120 characters)
            if line.count > 120 {
                issues.append([
                    "line": "\(lineNumber)",
                    "severity": "warning",
                    "message": "Line exceeds 120 characters (\(line.count) chars). Consider breaking into multiple lines."
                ])
            }

            // Detect missing access control on func/class/struct declarations
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
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

/// Checks Swift code for common security anti-patterns.
public struct CheckSecurityPatternsTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let code: String
    }
    public typealias Output = String

    public static let name = "checkSecurityPatterns"
    public static let description = "Checks Swift code for security anti-patterns: hardcoded passwords, API keys, force unwraps in security-critical paths."
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("code", .string(description: "The Swift source code to scan for security issues."))
                ],
                required: ["code"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        var findings: [[String: String]] = []
        let lines = input.code.components(separatedBy: "\n")

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

            // Skip comments
            if trimmed.hasPrefix("//") { continue }

            for (pattern, risk, message) in securityPatterns {
                let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSRange(line.startIndex..., in: line)
                if let _ = regex?.firstMatch(in: line, range: range) {
                    findings.append([
                        "line": "\(lineNumber)",
                        "risk": risk,
                        "pattern": pattern,
                        "message": message
                    ])
                }
            }
        }

        let data = try JSONSerialization.data(withJSONObject: findings, options: [.sortedKeys])
        return String(data: data, encoding: .utf8) ?? "[]"
    }
}

/// Generates a formatted patch suggestion for a specific issue.
public struct SuggestPatchTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let file: String
        public let issue: String
        public let suggestion: String
    }
    public typealias Output = String

    public static let name = "suggestPatch"
    public static let description = "Generates a formatted patch suggestion for a specific code issue."
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("file", .string(description: "The file path where the issue was found.")),
                    ("issue", .string(description: "Description of the issue to fix.")),
                    ("suggestion", .string(description: "The suggested code change."))
                ],
                required: ["file", "issue", "suggestion"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        return """
        --- Patch Suggestion ---
        File: \(input.file)
        Issue: \(input.issue)

        Suggested Change:
        ```swift
        \(input.suggestion)
        ```
        """
    }
}

/// Formats review findings and patch suggestions into a Markdown report.
public struct FormatReviewTool: AgentToolProtocol {
    public struct Input: Codable, Sendable {
        public let findings: String
        public let patches: String
    }
    public typealias Output = String

    public static let name = "formatReview"
    public static let description = "Formats review findings and patch suggestions into a structured Markdown report."
    public static let isConcurrencySafe = true

    public static var inputSchema: FunctionToolParam {
        FunctionToolParam(
            name: name,
            description: description,
            parameters: .object(
                properties: [
                    ("findings", .string(description: "JSON string of findings from analysis and security checks.")),
                    ("patches", .string(description: "JSON string or text of suggested patches."))
                ],
                required: ["findings", "patches"]
            ),
            strict: true
        )
    }

    public func execute(input: Input) async throws -> String {
        return """
        ## Code Review Summary

        ### Findings

        \(input.findings)

        ### Suggested Patches

        \(input.patches)

        ---
        *Generated by PRReviewer Agent*
        """
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

    /// Legacy convenience init for backward compatibility.
    public init(serverURL: String, modelName: String, apiKey: String? = nil, maxRetries: Int = 3) throws {
        let config = try AgentConfiguration(serverURL: serverURL, modelName: modelName, apiKey: apiKey, maxRetries: maxRetries)
        try self.init(configuration: config)
    }

    public func execute(goal: String) async throws -> String {
        let client = try config.buildClient()

        let tools = ToolRegistry()
        tools.register(FetchDiffTool())
        tools.register(AnalyzeSwiftStyleTool())
        tools.register(CheckSecurityPatternsTool())
        tools.register(SuggestPatchTool())
        tools.register(FormatReviewTool())

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
