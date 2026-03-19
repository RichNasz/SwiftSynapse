# SwiftSynapse Project Vision

## Overview
SwiftSynapse is an open-source showcase and framework for building smart, autonomous AI agents natively in Swift for Apple platforms (iOS 18+, macOS 15+, visionOS).  
Agents are observable, background-capable, type-safe, and powered by declarative macros — enabling seamless integration into SwiftUI apps with minimal boilerplate.

## Core Goals
- Demonstrate production-grade agentic patterns using pure Swift (no Python bridges, no heavy frameworks).
- Provide runnable examples of agents (code review, performance optimization, task planning, etc.) built via spec-driven development.
- Lower the barrier for Swift developers to adopt agentic AI in their apps (on-device first via Foundation Models, hybrid cloud fallback).
- Showcase the full power of SwiftSynapseMacros + SwiftResponsesDSL + SwiftLLMToolMacros.

## Key Principles & Non-Negotiables
- AI-first, AI-always code generation: All implementation code, README, docs, and examples are generated from specifications via Claude Code (or equivalent). No human hand-written implementation code is permitted.
- Strict spec separation: Human/AI-refined specs live in VISION.md, CodeGenSpecs/, and per-agent folders. Generated artifacts (Sources/, README.md, etc.) are never manually edited.
- Type safety & compile-time guarantees: Heavy use of macros for tools, structured output, observability.
- Modern Swift: Swift 6.2+, actors, Observation (@Observable), strict concurrency, result builders.
- Apple-native: Foundation Models on-device priority, SwiftUI for interfaces, BGContinuedProcessingTask for background continuation.
- Zero extra runtime dependencies beyond Foundation (and existing DSL/macro libs).

## Target Use Cases in Showcase
- PRReviewer: Analyzes GitHub PRs for style/performance/security, suggests patches.
- PerformanceOptimizer: Identifies bottlenecks in Swift code, proposes optimizations.
- TaskPlanner: Multi-phase personal productivity agent with sub-agents.
- (more to come)

## Success Criteria
- Clone → open Xcode → run AgentDashboard → see live agent reasoning, tool calls, and UI updates.
- All agents observable via transcript (thoughts, steps, tool results).
- Background execution support (foreground start → continue in background).
- Easy to add new agents via copy-template + spec + generate.

## Branding
Name: SwiftSynapse  
Tagline: "Smart, autonomous agents in pure Swift – connected intelligence for Apple platforms"
Web: swiftsynapse.dev (or similar – to be registered)
Note: Not affiliated with unrelated sites like swiftsynapse.com.

Last updated: March 2026