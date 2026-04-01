// Generated strictly from Agents/SimpleEcho/specs/Overview.md + shared CodeGenSpecs/
// Do not edit manually — update the spec and re-generate

import SwiftSynapseHarness

@SpecDrivenAgent
public actor SimpleEcho {
    public init() {}

    public func execute(goal: String) async throws -> String {
        _transcript.append(.userMessage(goal))
        let echoed = "Echo from SwiftSynapse: \(goal)"
        _transcript.append(.assistantMessage(echoed))
        return echoed
    }
}
