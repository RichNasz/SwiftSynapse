// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftSynapse",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .visionOS(.v2),
    ],
    products: [
        .library(name: "SimpleEchoAgent",          targets: ["SimpleEchoAgent"]),
        .library(name: "LLMChatAgent",             targets: ["LLMChatAgent"]),
        .library(name: "LLMChatPersonasAgent",     targets: ["LLMChatPersonasAgent"]),
        .library(name: "RetryingLLMChatAgentAgent",targets: ["RetryingLLMChatAgentAgent"]),
        .library(name: "StreamingChatAgentAgent",  targets: ["StreamingChatAgentAgent"]),
        .library(name: "ToolUsingAgentAgent",      targets: ["ToolUsingAgentAgent"]),
        .library(name: "SkillsEnabledAgentAgent",  targets: ["SkillsEnabledAgentAgent"]),
        .library(name: "PRReviewerAgent",          targets: ["PRReviewerAgent"]),
        .library(name: "PerformanceOptimizerAgent",targets: ["PerformanceOptimizerAgent"]),
        .library(name: "ResearchAssistantAgent",   targets: ["ResearchAssistantAgent"]),
        .library(name: "TaskPlannerAgent",         targets: ["TaskPlannerAgent"]),
        .library(name: "DataPipelineAgentAgent",   targets: ["DataPipelineAgentAgent"]),
    ],
    dependencies: [
        .package(url: "https://github.com/RichNasz/SwiftSynapseHarness", branch: "main"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "SimpleEchoAgent",
            dependencies: [
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
            ],
            path: "Agents/SimpleEcho/Sources"
        ),
        .executableTarget(
            name: "simple-echo",
            dependencies: [
                "SimpleEchoAgent",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Agents/SimpleEcho/CLI"
        ),
        .testTarget(
            name: "SimpleEchoTests",
            dependencies: ["SimpleEchoAgent"],
            path: "Agents/SimpleEcho/Tests"
        ),
        .target(
            name: "LLMChatAgent",
            dependencies: [
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
            ],
            path: "Agents/LLMChat/Sources"
        ),
        .executableTarget(
            name: "llm-chat",
            dependencies: [
                "LLMChatAgent",
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Agents/LLMChat/CLI"
        ),
        .testTarget(
            name: "LLMChatTests",
            dependencies: [
                "LLMChatAgent",
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
            ],
            path: "Agents/LLMChat/Tests"
        ),
        .target(
            name: "LLMChatPersonasAgent",
            dependencies: [
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
            ],
            path: "Agents/LLMChatPersonas/Sources"
        ),
        .executableTarget(
            name: "llm-chat-personas",
            dependencies: [
                "LLMChatPersonasAgent",
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Agents/LLMChatPersonas/CLI"
        ),
        .testTarget(
            name: "LLMChatPersonasTests",
            dependencies: [
                "LLMChatPersonasAgent",
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
            ],
            path: "Agents/LLMChatPersonas/Tests"
        ),
        .target(
            name: "RetryingLLMChatAgentAgent",
            dependencies: [
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
            ],
            path: "Agents/RetryingLLMChatAgent/Sources"
        ),
        .executableTarget(
            name: "retrying-llm-chat-agent",
            dependencies: [
                "RetryingLLMChatAgentAgent",
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Agents/RetryingLLMChatAgent/CLI"
        ),
        .testTarget(
            name: "RetryingLLMChatAgentTests",
            dependencies: [
                "RetryingLLMChatAgentAgent",
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
            ],
            path: "Agents/RetryingLLMChatAgent/Tests"
        ),
        .target(
            name: "StreamingChatAgentAgent",
            dependencies: [
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
            ],
            path: "Agents/StreamingChatAgent/Sources"
        ),
        .executableTarget(
            name: "streaming-chat-agent",
            dependencies: [
                "StreamingChatAgentAgent",
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Agents/StreamingChatAgent/CLI"
        ),
        .testTarget(
            name: "StreamingChatAgentTests",
            dependencies: [
                "StreamingChatAgentAgent",
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
            ],
            path: "Agents/StreamingChatAgent/Tests"
        ),
        .target(
            name: "ToolUsingAgentAgent",
            dependencies: [
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
            ],
            path: "Agents/ToolUsingAgent/Sources"
        ),
        .executableTarget(
            name: "tool-using-agent",
            dependencies: [
                "ToolUsingAgentAgent",
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Agents/ToolUsingAgent/CLI"
        ),
        .testTarget(
            name: "ToolUsingAgentTests",
            dependencies: [
                "ToolUsingAgentAgent",
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
            ],
            path: "Agents/ToolUsingAgent/Tests"
        ),
        .target(
            name: "SkillsEnabledAgentAgent",
            dependencies: [
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
            ],
            path: "Agents/SkillsEnabledAgent/Sources"
        ),
        .executableTarget(
            name: "skills-enabled-agent",
            dependencies: [
                "SkillsEnabledAgentAgent",
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Agents/SkillsEnabledAgent/CLI"
        ),
        .testTarget(
            name: "SkillsEnabledAgentTests",
            dependencies: [
                "SkillsEnabledAgentAgent",
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
            ],
            path: "Agents/SkillsEnabledAgent/Tests"
        ),
        .target(
            name: "PRReviewerAgent",
            dependencies: [
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
            ],
            path: "Agents/PRReviewer/Sources"
        ),
        .executableTarget(
            name: "pr-reviewer",
            dependencies: [
                "PRReviewerAgent",
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Agents/PRReviewer/CLI"
        ),
        .testTarget(
            name: "PRReviewerTests",
            dependencies: [
                "PRReviewerAgent",
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
            ],
            path: "Agents/PRReviewer/Tests"
        ),
        .target(
            name: "PerformanceOptimizerAgent",
            dependencies: [
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
            ],
            path: "Agents/PerformanceOptimizer/Sources"
        ),
        .executableTarget(
            name: "performance-optimizer",
            dependencies: [
                "PerformanceOptimizerAgent",
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Agents/PerformanceOptimizer/CLI"
        ),
        .testTarget(
            name: "PerformanceOptimizerTests",
            dependencies: [
                "PerformanceOptimizerAgent",
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
            ],
            path: "Agents/PerformanceOptimizer/Tests"
        ),
        .target(
            name: "ResearchAssistantAgent",
            dependencies: [
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
            ],
            path: "Agents/ResearchAssistant/Sources"
        ),
        .executableTarget(
            name: "research-assistant",
            dependencies: [
                "ResearchAssistantAgent",
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Agents/ResearchAssistant/CLI"
        ),
        .testTarget(
            name: "ResearchAssistantTests",
            dependencies: [
                "ResearchAssistantAgent",
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
            ],
            path: "Agents/ResearchAssistant/Tests"
        ),
        .target(
            name: "TaskPlannerAgent",
            dependencies: [
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
            ],
            path: "Agents/TaskPlanner/Sources"
        ),
        .executableTarget(
            name: "task-planner",
            dependencies: [
                "TaskPlannerAgent",
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Agents/TaskPlanner/CLI"
        ),
        .testTarget(
            name: "TaskPlannerTests",
            dependencies: [
                "TaskPlannerAgent",
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
            ],
            path: "Agents/TaskPlanner/Tests"
        ),
        .target(
            name: "DataPipelineAgentAgent",
            dependencies: [
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
            ],
            path: "Agents/DataPipelineAgent/Sources"
        ),
        .executableTarget(
            name: "data-pipeline-agent",
            dependencies: [
                "DataPipelineAgentAgent",
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Agents/DataPipelineAgent/CLI"
        ),
        .testTarget(
            name: "DataPipelineAgentTests",
            dependencies: [
                "DataPipelineAgentAgent",
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
            ],
            path: "Agents/DataPipelineAgent/Tests"
        ),
        .executableTarget(
            name: "AgentDashboard",
            dependencies: [
                "SimpleEchoAgent",
                "LLMChatAgent",
                "LLMChatPersonasAgent",
                "RetryingLLMChatAgentAgent",
                "StreamingChatAgentAgent",
                "ToolUsingAgentAgent",
                "SkillsEnabledAgentAgent",
                "PRReviewerAgent",
                "PerformanceOptimizerAgent",
                "ResearchAssistantAgent",
                "TaskPlannerAgent",
                "DataPipelineAgentAgent",
                .product(name: "SwiftSynapseHarness", package: "SwiftSynapseHarness"),
                .product(name: "SwiftSynapseUI", package: "SwiftSynapseHarness"),
            ],
            path: "Apps/AgentDashboard"
        ),
    ]
)
