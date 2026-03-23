<!-- Generated from CodeGenSpecs/Agent-README-Generation.md + Agents/SimpleEcho/specs/SPEC.md — Do not edit manually. -->

# SimpleEcho

Echo user input back with a prefix — the simplest proof-of-concept agent in SwiftSynapse.

## Overview

SimpleEcho validates the spec-to-codegen pipeline with the minimal possible agent. It takes a string, prepends a prefix, and returns it. No LLM calls, no tools, no background execution — just the core agent lifecycle (input, transcript, output). It uses only the default shared patterns: observability via `ObservableTranscript` and `AgentStatus`, and the `@SpecDrivenAgent` macro.

**Platforms:** iOS 26+, macOS 26+, visionOS 2+

## Quick Start

**CLI:**

```bash
swift run simple-echo 'Hello, SwiftSynapse!'
```

**Programmatic:**

```swift
import SimpleEchoAgent

let agent = SimpleEcho()
let result = try await agent.execute(goal: "Hello, SwiftSynapse!")
print(result) // "Echo from SwiftSynapse: Hello, SwiftSynapse!"
```

**SwiftUI:**

```swift
import SwiftUI
import SimpleEchoAgent

struct EchoView: View {
    @State private var agent = SimpleEcho()

    var body: some View {
        // agent.status and agent.transcript.entries update automatically
    }
}
```

## Input

| Field | Type | Description |
|-------|------|-------------|
| `goal` | `String` | The user-provided text to echo back |

## Output

| Field | Type | Description |
|-------|------|-------------|
| return value | `String` | `"Echo from SwiftSynapse: \(goal)"` |
| `transcript` | `ObservableTranscript` | Updated with user + assistant entries |

## How It Works

1. **Validate input** — Check that `goal` is non-empty; throw `SimpleEchoError.emptyGoal` and set status to `.error(SimpleEchoError.emptyGoal)` if empty.
2. **Start running** — Set status to `.running`.
3. **Record user input** — Append a `.userMessage(goal)` transcript entry.
4. **Produce echo** — Build the echoed string: `"Echo from SwiftSynapse: \(goal)"`.
5. **Record output** — Append an `.assistantMessage` transcript entry with the echoed string.
6. **Complete** — Set status to `.completed(echoed)`.

## Transcript Example

```
[user]      Hello, SwiftSynapse!
[assistant] Echo from SwiftSynapse: Hello, SwiftSynapse!
```

## Errors

| Case | Thrown when |
|------|-------------|
| `SimpleEchoError.emptyGoal` | `goal` is an empty string |

## Testing

```bash
swift test --filter SimpleEchoTests
```

Tests validate:
- Transcript has exactly 2 entries after a successful run
- First entry is `.userMessage` with content matching the goal
- Second entry is `.assistantMessage` with content matching `"Echo from SwiftSynapse: \(goal)"`
- Status is `.completed` after success, `.error` after empty input
- Completes without throwing for any non-empty input

## Constraints

- Must not make any LLM calls
- Must not persist user data beyond the session
- Must handle empty input by throwing an error

## File Structure

```
Agents/SimpleEcho/
├── specs/
│   ├── SPEC.md
│   └── Overview.md
├── README.md
├── Sources/
│   └── SimpleEcho.swift
├── CLI/
│   └── SimpleEchoCLI.swift
└── Tests/
    └── SimpleEchoTests.swift
```

## Related

- [specs/SPEC.md](specs/SPEC.md) — agent specification
- [specs/Overview.md](specs/Overview.md) — generation rules
- [Root README.md](../../README.md) — project overview
