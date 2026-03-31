// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "SwiftSynapse",
    platforms: [
        .macOS(.v26),
        .iOS(.v26),
        .visionOS(.v2),
    ],
    dependencies: [
        .package(url: "https://github.com/RichNasz/SwiftSynapseMacros", branch: "main"),
        .package(url: "https://github.com/RichNasz/SwiftOpenResponsesDSL", branch: "main"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "SimpleEchoAgent",
            dependencies: [
                .product(name: "SwiftSynapseMacrosClient", package: "SwiftSynapseMacros"),
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
                .product(name: "SwiftSynapseMacrosClient", package: "SwiftSynapseMacros"),
                .product(name: "SwiftOpenResponsesDSL", package: "SwiftOpenResponsesDSL"),
            ],
            path: "Agents/LLMChat/Sources"
        ),
        .executableTarget(
            name: "llm-chat",
            dependencies: [
                "LLMChatAgent",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Agents/LLMChat/CLI"
        ),
        .testTarget(
            name: "LLMChatTests",
            dependencies: ["LLMChatAgent"],
            path: "Agents/LLMChat/Tests"
        ),
        .target(
            name: "LLMChatPersonasAgent",
            dependencies: [
                .product(name: "SwiftSynapseMacrosClient", package: "SwiftSynapseMacros"),
                .product(name: "SwiftOpenResponsesDSL", package: "SwiftOpenResponsesDSL"),
            ],
            path: "Agents/LLMChatPersonas/Sources"
        ),
        .executableTarget(
            name: "llm-chat-personas",
            dependencies: [
                "LLMChatPersonasAgent",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Agents/LLMChatPersonas/CLI"
        ),
        .testTarget(
            name: "LLMChatPersonasTests",
            dependencies: ["LLMChatPersonasAgent"],
            path: "Agents/LLMChatPersonas/Tests"
        ),
        .target(
            name: "RetryingLLMChatAgentAgent",
            dependencies: [
                .product(name: "SwiftSynapseMacrosClient", package: "SwiftSynapseMacros"),
                .product(name: "SwiftOpenResponsesDSL", package: "SwiftOpenResponsesDSL"),
            ],
            path: "Agents/RetryingLLMChatAgent/Sources"
        ),
        .executableTarget(
            name: "retrying-llm-chat-agent",
            dependencies: [
                "RetryingLLMChatAgentAgent",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Agents/RetryingLLMChatAgent/CLI"
        ),
        .testTarget(
            name: "RetryingLLMChatAgentTests",
            dependencies: ["RetryingLLMChatAgentAgent"],
            path: "Agents/RetryingLLMChatAgent/Tests"
        ),
        .target(
            name: "StreamingChatAgentAgent",
            dependencies: [
                .product(name: "SwiftSynapseMacrosClient", package: "SwiftSynapseMacros"),
                .product(name: "SwiftOpenResponsesDSL", package: "SwiftOpenResponsesDSL"),
            ],
            path: "Agents/StreamingChatAgent/Sources"
        ),
        .executableTarget(
            name: "streaming-chat-agent",
            dependencies: [
                "StreamingChatAgentAgent",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Agents/StreamingChatAgent/CLI"
        ),
        .testTarget(
            name: "StreamingChatAgentTests",
            dependencies: ["StreamingChatAgentAgent"],
            path: "Agents/StreamingChatAgent/Tests"
        ),
        .target(
            name: "ToolUsingAgentAgent",
            dependencies: [
                .product(name: "SwiftSynapseMacrosClient", package: "SwiftSynapseMacros"),
                .product(name: "SwiftOpenResponsesDSL", package: "SwiftOpenResponsesDSL"),
            ],
            path: "Agents/ToolUsingAgent/Sources"
        ),
        .executableTarget(
            name: "tool-using-agent",
            dependencies: [
                "ToolUsingAgentAgent",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Agents/ToolUsingAgent/CLI"
        ),
        .testTarget(
            name: "ToolUsingAgentTests",
            dependencies: ["ToolUsingAgentAgent"],
            path: "Agents/ToolUsingAgent/Tests"
        ),
    ]
)
