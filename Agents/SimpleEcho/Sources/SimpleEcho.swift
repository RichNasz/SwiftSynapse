// Generated strictly from Agents/SimpleEcho/CodeGen/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import SwiftSynapseMacrosClient

@SpecDrivenAgent
public actor SimpleEcho {
    public enum SimpleEchoError: Error, Sendable {
        case emptyGoal
    }

    public init() {}

    public func run(goal: String) async throws -> String {
        guard !goal.isEmpty else {
            _status = .failed
            throw SimpleEchoError.emptyGoal
        }
        _status = .running
        _transcript.append(.userMessage(goal))
        let echoed = "Echo from SwiftSynapse: \(goal)"
        _transcript.append(.assistantMessage(echoed))
        _status = .completed
        return echoed
    }
}
