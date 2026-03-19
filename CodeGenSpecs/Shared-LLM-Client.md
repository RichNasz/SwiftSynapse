# Shared Spec: LLM Client

> Defines the shared LLM client protocol that all agents use to communicate with language models.

---

## Summary

All agents interact with language models through a single `LLMClient` protocol, never by calling any SDK directly. This allows the concrete provider (Apple Foundation Models, a remote REST endpoint, etc.) to be injected at runtime and swapped in tests. The protocol exposes a single async streaming method that yields `TranscriptDelta` values and throws on error.

Concrete implementations of `LLMClient` are generated from `Shared-LLM-Client.md` and live in a shared module. Agents never instantiate an LLM client themselves; they receive one via initializer injection.

[Detailed rules to be expanded]
