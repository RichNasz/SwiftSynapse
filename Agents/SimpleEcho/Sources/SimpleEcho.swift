// Generated strictly from Agents/SimpleEcho/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import SwiftSynapseMacrosClient

@SpecDrivenAgent
public actor SimpleEcho {
    public enum SimpleEchoError: Error, Sendable {
        case emptyGoal
    }

    public init() {}

    public func execute(goal: String) async throws -> String {
        guard !goal.isEmpty else {
            _status = .error(SimpleEchoError.emptyGoal)
            throw SimpleEchoError.emptyGoal
        }
        _status = .running
        _transcript.reset()
        _transcript.append(.userMessage(goal))
        let echoed = "Echo from SwiftSynapse: \(goal)"
        _transcript.append(.assistantMessage(echoed))
        _status = .completed(echoed)
        return echoed
    }
}
