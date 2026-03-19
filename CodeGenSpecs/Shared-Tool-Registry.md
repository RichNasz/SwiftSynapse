# Shared Spec: Tool Registry

> Defines how LLM tools are registered, discovered, and dispatched across all SwiftSynapse agents.

---

## Summary

Each agent owns a `ToolRegistry` that holds the set of `@LLMTool`-annotated functions it exposes to the language model. The registry is built at agent initialization time by reflecting over the agent's generated tool descriptors. When the LLM emits a tool call, the registry routes it to the correct Swift function, marshals arguments, and returns the result as a structured response.

Tool schemas are generated automatically from `@LLMTool` macros (SwiftLLMToolMacros); no JSON schema is written by hand. Tools that perform side effects (network calls, file I/O) must declare their effects in the spec so the generator can wrap them with appropriate error handling and timeout logic.

[Detailed rules to be expanded]
