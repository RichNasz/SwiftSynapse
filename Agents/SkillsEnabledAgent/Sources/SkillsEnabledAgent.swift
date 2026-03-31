// Generated strictly from Agents/SkillsEnabledAgent/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import Foundation
import SwiftSynapseMacrosClient

public enum SkillsEnabledAgentError: Error, Sendable {
    case emptyGoal
    case noResponseContent
}

@SpecDrivenAgent
public actor SkillsEnabledAgent {
    private let config: AgentConfiguration
    private let skillStore: SkillStore

    public init(configuration: AgentConfiguration) throws {
        self.config = configuration
        self.skillStore = SkillStore()
    }

    public func execute(goal: String) async throws -> String {
        guard !goal.isEmpty else {
            _status = .error(SkillsEnabledAgentError.emptyGoal)
            throw SkillsEnabledAgentError.emptyGoal
        }

        _status = .running
        _transcript.reset()
        _transcript.append(.userMessage(goal))

        // Discover skills from standard filesystem locations
        let store = skillStore
        try await store.load()

        // Build a SkillsAgent with activate_skill tool and skill catalog in system prompt
        let client = try config.buildLLMClient()
        let agent = try await SkillsAgent(
            client: client,
            model: config.modelName,
            maxToolIterations: 10
        ) {
            Skills(store: store)
        }

        let result: String
        do {
            result = try await agent.send(goal)
        } catch {
            _status = .error(error)
            throw error
        }

        guard !result.isEmpty else {
            _status = .error(SkillsEnabledAgentError.noResponseContent)
            throw SkillsEnabledAgentError.noResponseContent
        }

        _transcript.append(.assistantMessage(result))
        _status = .completed(result)
        return result
    }
}
