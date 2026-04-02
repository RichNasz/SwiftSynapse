# Shared Spec: Configuration Hierarchy

> Core trait — 7-level priority configuration resolution from multiple sources.

---

## Summary

Extends `AgentConfiguration` (see `Shared-Configuration.md`) with a multi-source resolution system. Configuration values can come from environment variables, JSON files, MDM profiles, and CLI arguments, with a defined priority order.

---

## Core Types

### ConfigurationPriority (7 Levels)

```swift
public enum ConfigurationPriority: Int, Comparable, Sendable {
    case environment = 0        // SWIFTSYNAPSE_* env vars (lowest)
    case remote = 1             // remote config service
    case mdm = 2                // MDM profile (managed devices)
    case user = 3               // ~/.config/swiftsynapse/config.json
    case project = 4            // .swiftsynapse/config.json in project root
    case local = 5              // local overrides
    case cliArguments = 6       // --server-url, --model flags (highest)
}
```

Higher priority wins when multiple sources provide the same key.

### ConfigurationSource Protocol

```swift
public protocol ConfigurationSource: Sendable {
    var priority: ConfigurationPriority { get }
    func value(for key: String) -> String?
}
```

### Built-in Sources

```swift
public struct EnvironmentConfigSource: ConfigurationSource    // reads env vars
public struct FileConfigSource: ConfigurationSource {         // reads JSON files
    public static let userDefault: FileConfigSource           // ~/.config/swiftsynapse/config.json
    public static let projectDefault: FileConfigSource        // .swiftsynapse/config.json
}
public struct MDMConfigSource: ConfigurationSource            // reads MDM managed preferences
```

### ConfigurationResolver

```swift
public struct ConfigurationResolver: Sendable {
    public init(_ sources: [any ConfigurationSource])
    public func resolve(key: String) -> String?    // returns highest-priority value
}
```

---

## Integration Points

- **AgentConfiguration**: `fromEnvironment(overrides:)` uses the resolver internally
- **CLI targets**: CLI argument parsers register as `cliArguments` priority source
- **MDM**: enterprise deployments can lock configuration via managed profiles
- The basic `AgentConfiguration.fromEnvironment()` pattern from `Shared-Configuration.md` remains the primary API for most agents; the hierarchy is the underlying mechanism.
