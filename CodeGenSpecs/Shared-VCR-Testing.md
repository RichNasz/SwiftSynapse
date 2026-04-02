# Shared Spec: VCR Testing

> Test support — record and replay LLM interactions for deterministic tests.

---

## Summary

VCR (Video Cassette Recorder) testing records LLM API interactions during test runs and replays them for subsequent runs. This enables fast, deterministic, and offline testing without requiring a live LLM endpoint.

---

## Core Types

### VCRMode

```swift
public enum VCRMode: Sendable {
    case record         // record all interactions to a cassette file
    case replay         // replay from a cassette file (fail if no recording found)
    case passthrough    // bypass VCR, use live API (default in non-test builds)
}
```

### VCRRecording

```swift
public struct VCRRecording: Codable, Sendable {
    public let interactions: [VCRInteraction]
}

public struct VCRInteraction: Codable, Sendable {
    public let request: VCRRequest
    public let response: VCRResponse
}
```

---

## Usage Pattern

```swift
// In tests:
let cassette = try VCRRecording.load(from: "Fixtures/llm-chat-happy-path.json")
let client = VCRLLMClient(recording: cassette, mode: .replay)

let agent = try LLMChat(configuration: config)
agent.configure(client: client)

let result = try await agent.run(goal: "Hello")
// Uses recorded response — no network call
```

---

## Rules

- VCR recordings are stored as JSON files in `Tests/Fixtures/`.
- Recordings capture request/response pairs in order — replay is positional.
- In `.replay` mode, if the request doesn't match the next recording, the test fails.
- VCR is a test-only utility — not part of any production trait.
