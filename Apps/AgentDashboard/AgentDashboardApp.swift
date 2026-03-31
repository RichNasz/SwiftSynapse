// Generated from CodeGenSpecs — Do not edit manually. Update spec and re-generate.

import SwiftUI
import SwiftSynapseUI
import SwiftSynapseMacrosClient
import LLMChatAgent
import StreamingChatAgentAgent
import ToolUsingAgentAgent
import SimpleEchoAgent

@main
struct AgentDashboardApp: App {
    var body: some Scene {
        WindowGroup {
            DashboardView()
        }
        #if os(macOS)
        .defaultSize(width: 800, height: 600)
        #endif
    }
}

struct DashboardView: View {
    enum AgentSelection: String, CaseIterable, Identifiable {
        case echo = "SimpleEcho"
        case llmChat = "LLMChat"
        case streaming = "StreamingChat"
        case toolUsing = "ToolUsing"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .echo: return "Simple Echo"
            case .llmChat: return "LLM Chat"
            case .streaming: return "Streaming Chat"
            case .toolUsing: return "Tool Using"
            }
        }

        var description: String {
            switch self {
            case .echo: return "Echoes input back — no LLM needed"
            case .llmChat: return "Single LLM call with retry"
            case .streaming: return "Token-by-token streaming"
            case .toolUsing: return "Math and unit conversion tools"
            }
        }

        var systemImage: String {
            switch self {
            case .echo: return "repeat"
            case .llmChat: return "bubble.left.and.bubble.right"
            case .streaming: return "text.word.spacing"
            case .toolUsing: return "wrench.and.screwdriver"
            }
        }
    }

    @State private var selectedAgent: AgentSelection = .echo
    @State private var inputText = ""
    @State private var isRunning = false
    @State private var currentTranscript = ObservableTranscript()
    @State private var currentStatus: AgentStatus = .idle
    @State private var errorMessage: String?

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detailView
        }
    }

    private var sidebar: some View {
        List(AgentSelection.allCases, selection: $selectedAgent) { agent in
            Label {
                VStack(alignment: .leading) {
                    Text(agent.displayName)
                        .fontWeight(.medium)
                    Text(agent.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: agent.systemImage)
                    .foregroundStyle(.blue)
            }
            .tag(agent)
        }
        .navigationTitle("Agents")
        #if os(macOS)
        .navigationSplitViewColumnWidth(min: 200, ideal: 250)
        #endif
    }

    private var detailView: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label(selectedAgent.displayName, systemImage: selectedAgent.systemImage)
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                AgentStatusView(status: currentStatus)
            }
            .padding()

            Divider()

            // Transcript
            if currentTranscript.entries.isEmpty && !currentTranscript.isStreaming {
                ContentUnavailableView(
                    "No Activity",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Enter a goal below to start the \(selectedAgent.displayName) agent.")
                )
            } else {
                TranscriptView(transcript: currentTranscript)
            }

            // Error banner
            if let errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(errorMessage)
                        .font(.callout)
                    Spacer()
                    Button("Dismiss") {
                        self.errorMessage = nil
                    }
                    .buttonStyle(.borderless)
                }
                .padding(8)
                .background(.red.opacity(0.1))
            }

            Divider()

            // Input
            HStack(spacing: 8) {
                TextField("Enter a goal...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { sendGoal() }
                    .disabled(isRunning)

                Button {
                    sendGoal()
                } label: {
                    if isRunning {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isRunning)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()
        }
        .navigationTitle(selectedAgent.displayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onChange(of: selectedAgent) { _, _ in
            currentTranscript = ObservableTranscript()
            currentStatus = .idle
            errorMessage = nil
        }
    }

    private func sendGoal() {
        let goal = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !goal.isEmpty, !isRunning else { return }

        inputText = ""
        isRunning = true
        errorMessage = nil
        currentStatus = .running

        Task {
            do {
                switch selectedAgent {
                case .echo:
                    let agent = SimpleEcho()
                    _ = try await agent.execute(goal: goal)
                    currentTranscript = await agent.transcript
                    currentStatus = await agent.status

                case .llmChat:
                    let config = try AgentConfiguration.fromEnvironment()
                    let agent = try LLMChat(configuration: config)
                    _ = try await agent.execute(goal: goal)
                    currentTranscript = await agent.transcript
                    currentStatus = await agent.status

                case .streaming:
                    let config = try AgentConfiguration.fromEnvironment()
                    let agent = try StreamingChatAgent(configuration: config)
                    currentTranscript = await agent.transcript
                    _ = try await agent.execute(goal: goal)
                    currentStatus = await agent.status

                case .toolUsing:
                    let config = try AgentConfiguration.fromEnvironment()
                    let agent = try ToolUsingAgent(configuration: config)
                    _ = try await agent.execute(goal: goal)
                    currentTranscript = await agent.transcript
                    currentStatus = await agent.status
                }
            } catch {
                currentStatus = .error(error)
                errorMessage = error.localizedDescription
            }
            isRunning = false
        }
    }
}
