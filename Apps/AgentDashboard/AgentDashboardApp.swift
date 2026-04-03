// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import SwiftUI
import Foundation
import SwiftSynapseHarness
import SwiftSynapseUI
import SimpleEchoAgent
import LLMChatAgent
import LLMChatPersonasAgent
import RetryingLLMChatAgentAgent
import StreamingChatAgentAgent
import ToolUsingAgentAgent
import SkillsEnabledAgentAgent
import PRReviewerAgent
import PerformanceOptimizerAgent
import ResearchAssistantAgent
import TaskPlannerAgent
import DataPipelineAgentAgent

// MARK: - AgentTier

enum AgentTier: String, CaseIterable {
    case foundation = "Foundation"
    case advanced   = "Advanced"

    var displayName: String { rawValue }
}

// MARK: - AgentID

enum AgentID: String, CaseIterable, Identifiable, Hashable, Sendable {
    // Foundation tier
    case simpleEcho           = "SimpleEcho"
    case llmChat              = "LLMChat"
    case llmChatPersonas      = "LLMChatPersonas"
    case retryingLLMChat      = "RetryingLLMChatAgent"
    case streamingChat        = "StreamingChatAgent"
    case toolUsing            = "ToolUsingAgent"
    case skillsEnabled        = "SkillsEnabledAgent"
    // Advanced tier
    case prReviewer           = "PRReviewer"
    case performanceOptimizer = "PerformanceOptimizer"
    case researchAssistant    = "ResearchAssistant"
    case taskPlanner          = "TaskPlanner"
    case dataPipeline         = "DataPipelineAgent"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .simpleEcho:           return "Simple Echo"
        case .llmChat:              return "LLM Chat"
        case .llmChatPersonas:      return "LLM Chat Personas"
        case .retryingLLMChat:      return "Retrying LLM Chat"
        case .streamingChat:        return "Streaming Chat"
        case .toolUsing:            return "Tool Using"
        case .skillsEnabled:        return "Skills Enabled"
        case .prReviewer:           return "PR Reviewer"
        case .performanceOptimizer: return "Performance Optimizer"
        case .researchAssistant:    return "Research Assistant"
        case .taskPlanner:          return "Task Planner"
        case .dataPipeline:         return "Data Pipeline"
        }
    }

    var agentDescription: String {
        switch self {
        case .simpleEcho:           return "Echoes input back — no LLM needed"
        case .llmChat:              return "Single LLM call with retry"
        case .llmChatPersonas:      return "Two-step pipeline with optional persona rewrite"
        case .retryingLLMChat:      return "LLM chat with exponential-backoff retry and transcript annotations"
        case .streamingChat:        return "Token-by-token streaming response"
        case .toolUsing:            return "Math and unit conversion via LLM tool dispatch"
        case .skillsEnabled:        return "agentskills.io integration with skill discovery"
        case .prReviewer:           return "Code review with guardrails, permissions, and human-in-the-loop"
        case .performanceOptimizer: return "Performance analysis with recovery chains and rate limiting"
        case .researchAssistant:    return "Long-running research with session persistence and MCP"
        case .taskPlanner:          return "Multi-agent coordination with cost tracking and telemetry"
        case .dataPipeline:         return "Extensible data processing via plugin architecture"
        }
    }

    var systemImage: String {
        switch self {
        case .simpleEcho:           return "repeat"
        case .llmChat:              return "bubble.left.and.bubble.right"
        case .llmChatPersonas:      return "person.wave.2"
        case .retryingLLMChat:      return "arrow.trianglehead.clockwise"
        case .streamingChat:        return "text.word.spacing"
        case .toolUsing:            return "wrench.and.screwdriver"
        case .skillsEnabled:        return "bolt.shield"
        case .prReviewer:           return "checklist"
        case .performanceOptimizer: return "gauge.with.dots.needle.67percent"
        case .researchAssistant:    return "magnifyingglass.circle"
        case .taskPlanner:          return "list.bullet.clipboard"
        case .dataPipeline:         return "cylinder.split.1x2"
        }
    }

    var tier: AgentTier {
        switch self {
        case .simpleEcho, .llmChat, .llmChatPersonas, .retryingLLMChat,
             .streamingChat, .toolUsing, .skillsEnabled:
            return .foundation
        case .prReviewer, .performanceOptimizer, .researchAssistant,
             .taskPlanner, .dataPipeline:
            return .advanced
        }
    }

    var requiresLLM: Bool {
        self != .simpleEcho
    }
}

// MARK: - DashboardModel

@MainActor
@Observable
final class DashboardModel {
    var selectedAgent: AgentID?                  = .simpleEcho
    var goalText: String                         = ""
    var personaText: String                      = ""
    var isRunning: Bool                          = false
    var currentTranscript: ObservableTranscript  = ObservableTranscript()
    var currentStatus: AgentStatus               = .idle
    var errorMessage: String?                    = nil
    var showingConfiguration: Bool               = false
    var configServerURL: String
    var configModelName: String
    var configAPIKey: String
    private var currentTask: Task<Void, Never>?  = nil

    init() {
        let defaults = UserDefaults.standard
        configServerURL = defaults.string(forKey: "dashboard.serverURL") ?? "http://localhost:1234"
        configModelName = defaults.string(forKey: "dashboard.modelName") ?? "lmstudio-community/qwen3-8b"
        configAPIKey    = defaults.string(forKey: "dashboard.apiKey")    ?? ""
    }

    func sendGoal() {
        let goal = goalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !goal.isEmpty else {
            errorMessage = "Please enter a goal."
            return
        }
        guard !isRunning else { return }

        let agentID = selectedAgent
        goalText      = ""
        isRunning     = true
        errorMessage  = nil
        currentStatus = .running

        currentTask = Task { @MainActor in
            do {
                switch agentID {

                case .simpleEcho:
                    let agent = SimpleEcho()
                    currentTranscript = await agent.transcript
                    _ = try await agent.run(goal: goal)
                    currentStatus = await agent.status

                case .llmChat:
                    let config = try buildConfiguration()
                    let agent  = try LLMChat(configuration: config)
                    currentTranscript = await agent.transcript
                    _ = try await agent.run(goal: goal)
                    currentStatus = await agent.status

                case .llmChatPersonas:
                    let config  = try buildConfiguration()
                    let agent   = try LLMChatPersonas(configuration: config)
                    let persona: String? = personaText.isEmpty ? nil : personaText
                    currentTranscript = await agent.transcript
                    _ = try await agent.runWithPersona(goal: goal, persona: persona)
                    currentStatus = await agent.status

                case .retryingLLMChat:
                    let config = try buildConfiguration()
                    let agent  = try RetryingLLMChatAgent(configuration: config)
                    currentTranscript = await agent.transcript
                    _ = try await agent.run(goal: goal)
                    currentStatus = await agent.status

                case .streamingChat:
                    let config = try buildConfiguration()
                    let agent  = try StreamingChatAgent(configuration: config)
                    currentTranscript = await agent.transcript   // CRITICAL: before run()
                    _ = try await agent.run(goal: goal)
                    currentStatus = await agent.status

                case .toolUsing:
                    let config = try buildConfiguration()
                    let agent  = try ToolUsingAgent(configuration: config)
                    currentTranscript = await agent.transcript
                    _ = try await agent.run(goal: goal)
                    currentStatus = await agent.status

                case .skillsEnabled:
                    let config = try buildConfiguration()
                    let agent  = try SkillsEnabledAgent(configuration: config)
                    currentTranscript = await agent.transcript
                    _ = try await agent.run(goal: goal)
                    currentStatus = await agent.status

                case .prReviewer:
                    let config = try buildConfiguration()
                    let agent  = try PRReviewer(configuration: config)
                    currentTranscript = await agent.transcript
                    _ = try await agent.run(goal: goal)
                    currentStatus = await agent.status

                case .performanceOptimizer:
                    let config = try buildConfiguration()
                    let agent  = try PerformanceOptimizer(configuration: config)
                    currentTranscript = await agent.transcript
                    _ = try await agent.run(goal: goal)
                    currentStatus = await agent.status

                case .researchAssistant:
                    let config = try buildConfiguration()
                    let agent  = try ResearchAssistant(configuration: config)
                    currentTranscript = await agent.transcript
                    _ = try await agent.run(goal: goal)
                    currentStatus = await agent.status

                case .taskPlanner:
                    let config = try buildConfiguration()
                    let agent  = try TaskPlanner(configuration: config)
                    currentTranscript = await agent.transcript
                    _ = try await agent.run(goal: goal)
                    currentStatus = await agent.status

                case .dataPipeline:
                    let config = try buildConfiguration()
                    let agent  = try DataPipelineAgent(configuration: config)
                    currentTranscript = await agent.transcript
                    _ = try await agent.run(goal: goal)
                    currentStatus = await agent.status

                case .none:
                    break
                }

            } catch is CancellationError {
                currentStatus = .idle

            } catch {
                currentStatus = .error(error)
                errorMessage  = error.localizedDescription
            }
            isRunning   = false
            currentTask = nil
        }
    }

    func cancelCurrentRun() {
        currentTask?.cancel()
        isRunning     = false
        currentStatus = .idle
    }

    func clearTranscript() {
        currentTranscript = ObservableTranscript()
        currentStatus     = .idle
        errorMessage      = nil
    }

    func saveConfiguration() {
        let defaults = UserDefaults.standard
        defaults.set(configServerURL, forKey: "dashboard.serverURL")
        defaults.set(configModelName, forKey: "dashboard.modelName")
        defaults.set(configAPIKey,    forKey: "dashboard.apiKey")
        showingConfiguration = false
    }

    func buildConfiguration() throws -> AgentConfiguration {
        guard !configServerURL.isEmpty, URL(string: configServerURL) != nil else {
            throw AgentConfigurationError.invalidServerURL
        }
        guard !configModelName.isEmpty else {
            throw AgentConfigurationError.emptyModelName
        }
        return AgentConfiguration(
            serverURL: configServerURL,
            modelName: configModelName,
            apiKey: configAPIKey.isEmpty ? nil : configAPIKey
        )
    }

    func agentSelectionChanged() {
        clearTranscript()
        goalText    = ""
        personaText = ""
    }
}

// MARK: - AgentDashboardApp

@main
struct AgentDashboardApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardView()
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 720)
        #endif
        #if os(visionOS)
        .defaultSize(width: 900, height: 680)
        .windowStyle(.plain)
        #endif
    }
}

// MARK: - DashboardView

struct DashboardView: View {
    @State private var model = DashboardModel()

    var body: some View {
        NavigationSplitView {
            SidebarView(model: model)
        } detail: {
            DetailView(model: model)
        }
        .onChange(of: model.selectedAgent) { _, _ in
            model.agentSelectionChanged()
        }
        .sheet(isPresented: $model.showingConfiguration) {
            ConfigurationSheet(model: model)
        }
    }
}

// MARK: - SidebarView

struct SidebarView: View {
    var model: DashboardModel

    var body: some View {
        List(
            selection: Binding(
                get: { model.selectedAgent },
                set: { model.selectedAgent = $0 }
            )
        ) {
            ForEach(AgentTier.allCases, id: \.self) { tier in
                Section(tier.displayName) {
                    ForEach(AgentID.allCases.filter { $0.tier == tier }) { agent in
                        AgentRowView(agent: agent)
                            .tag(agent)
                    }
                }
            }
        }
        .navigationTitle("Agents")
        #if os(macOS)
        .navigationSplitViewColumnWidth(min: 200, ideal: 260)
        #endif
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    model.showingConfiguration = true
                } label: {
                    Label("Settings", systemImage: "gear")
                }
                .accessibilityLabel("Open Settings")
                .accessibilityHint("Configure the LLM endpoint and model")
            }
        }
    }
}

// MARK: - AgentRowView

struct AgentRowView: View {
    let agent: AgentID

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.displayName)
                    .fontWeight(.medium)
                Text(agent.agentDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: agent.systemImage)
                .foregroundStyle(Color.accentColor)
        }
        .accessibilityLabel(agent.displayName)
        .accessibilityHint(agent.agentDescription)
    }
}

// MARK: - DetailView

struct DetailView: View {
    var model: DashboardModel

    var body: some View {
        if let agent = model.selectedAgent {
            AgentDetailView(agent: agent, model: model)
        } else {
            ContentUnavailableView(
                "Select an Agent",
                systemImage: "sidebar.left",
                description: Text("Choose an agent from the sidebar to begin.")
            )
        }
    }
}

// MARK: - AgentDetailView

struct AgentDetailView: View {
    let agent: AgentID
    var model: DashboardModel

    var body: some View {
        VStack(spacing: 0) {

            // Transcript area
            if model.currentTranscript.entries.isEmpty && !model.currentTranscript.isStreaming {
                ContentUnavailableView(
                    "No Activity",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Enter a goal below to run the \(agent.displayName) agent.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        TranscriptView(transcript: model.currentTranscript)
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .onChange(of: model.currentTranscript.entries.count) { _, _ in
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }

            // Streaming indicator
            if model.currentTranscript.isStreaming {
                StreamingTextView(transcript: model.currentTranscript)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
            }

            // Error banner
            if let msg = model.errorMessage {
                ErrorBannerView(
                    message: msg,
                    onRetry: { model.sendGoal() },
                    onDismiss: { model.errorMessage = nil }
                )
                .padding(.horizontal)
                .padding(.vertical, 4)
            }

            Divider()

            // Persona field — LLMChatPersonas only
            if model.selectedAgent == .llmChatPersonas {
                PersonaInputView(
                    persona: Binding(
                        get: { model.personaText },
                        set: { model.personaText = $0 }
                    )
                )
                Divider()
            }

            // Goal input
            GoalInputView(
                text: Binding(
                    get: { model.goalText },
                    set: { model.goalText = $0 }
                ),
                isRunning: model.isRunning,
                onSend: { model.sendGoal() },
                onCancel: { model.cancelCurrentRun() }
            )
            .padding()
        }
        .navigationTitle(agent.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .principal) {
                AgentStatusView(status: model.currentStatus)
            }
            ToolbarItem(placement: .automatic) {
                Button("Clear") {
                    model.clearTranscript()
                }
                .disabled(model.isRunning)
                .accessibilityLabel("Clear transcript")
                .accessibilityHint("Removes all transcript entries and resets the agent status")
            }
        }
    }
}

// MARK: - ErrorBannerView

struct ErrorBannerView: View {
    let message: String
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.callout)
            Spacer()
            Button("Retry", action: onRetry)
                .buttonStyle(.borderless)
                .accessibilityLabel("Retry the last goal")
            Button("Dismiss", action: onDismiss)
                .buttonStyle(.borderless)
                .accessibilityLabel("Dismiss this error")
        }
        .padding(8)
        .background(.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - PersonaInputView

struct PersonaInputView: View {
    @Binding var persona: String

    var body: some View {
        HStack {
            Label("Persona", systemImage: "person.crop.circle")
                .foregroundStyle(.secondary)
            TextField("e.g. \"pirate\" or leave blank", text: $persona)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Persona")
                .accessibilityHint("Optional persona for the agent to adopt when responding")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}

// MARK: - GoalInputView

struct GoalInputView: View {
    @Binding var text: String
    let isRunning: Bool
    let onSend: () -> Void
    let onCancel: () -> Void

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        HStack(spacing: 8) {
            TextField("Enter a goal…", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .disabled(isRunning)
                .accessibilityLabel("Goal input")
                .accessibilityHint("Type a goal and press Send or ⌘↩")
                .onSubmit {
                    if !isRunning { onSend() }
                }

            Button {
                if isRunning { onCancel() } else { onSend() }
            } label: {
                if isRunning {
                    Label("Stop", systemImage: "stop.circle.fill")
                } else {
                    Label("Send", systemImage: "paperplane.fill")
                }
            }
            .disabled(!isRunning && trimmed.isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
        }
    }
}

// MARK: - ConfigurationSheet

struct ConfigurationSheet: View {
    var model: DashboardModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("LLM Endpoint") {
                    TextField(
                        "Server URL",
                        text: Binding(
                            get: { model.configServerURL },
                            set: { model.configServerURL = $0 }
                        )
                    )
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    #endif
                    .accessibilityLabel("Server URL")
                    .accessibilityHint("The base URL of your LLM server, e.g. http://localhost:1234")
                }

                Section("Model") {
                    TextField(
                        "Model name",
                        text: Binding(
                            get: { model.configModelName },
                            set: { model.configModelName = $0 }
                        )
                    )
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .accessibilityLabel("Model name")
                    .accessibilityHint("The model identifier string, e.g. lmstudio-community/qwen3-8b")
                }

                Section("API Key") {
                    SecureField(
                        "Optional API key",
                        text: Binding(
                            get: { model.configAPIKey },
                            set: { model.configAPIKey = $0 }
                        )
                    )
                    .accessibilityLabel("API key")
                    .accessibilityHint("Optional bearer token for authenticated LLM endpoints")
                }

                Section {
                    Button("Save & Close") {
                        model.saveConfiguration()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Save configuration and close")

                    Button("Restore Defaults", role: .destructive) {
                        model.configServerURL = "http://localhost:1234"
                        model.configModelName = "lmstudio-community/qwen3-8b"
                        model.configAPIKey    = ""
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Restore default configuration values")
                }
            }
            .navigationTitle("Configuration")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            #endif
        }
    }
}
