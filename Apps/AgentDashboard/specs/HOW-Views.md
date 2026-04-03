# HOW: Views

> Prescribes the exact view structure, layout, accessibility modifiers, and platform conditionals for AgentDashboardApp.swift.

---

## `AgentDashboardApp`

```swift
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
```

---

## `DashboardView`

```swift
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
```

---

## `SidebarView`

```swift
struct SidebarView: View {
    var model: DashboardModel

    var body: some View {
        List(selection: Binding(
            get: { model.selectedAgent },
            set: { model.selectedAgent = $0 }
        )) {
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
```

---

## `AgentRowView`

```swift
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
                .foregroundStyle(.accent)
        }
        .accessibilityLabel(agent.displayName)
        .accessibilityHint(agent.agentDescription)
    }
}
```

---

## `DetailView`

```swift
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
```

---

## `AgentDetailView`

```swift
struct AgentDetailView: View {
    let agent: AgentID
    var model: DashboardModel

    var body: some View {
        VStack(spacing: 0) {

            // ── Transcript ──────────────────────────────────────────────
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

            // ── Streaming indicator ──────────────────────────────────────
            if model.currentTranscript.isStreaming {
                StreamingTextView(text: model.currentTranscript.streamingText)
                    .padding(.horizontal)
                    .padding(.vertical, 4)
            }

            // ── Error banner ─────────────────────────────────────────────
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

            // ── Persona field (LLMChatPersonas only) ─────────────────────
            if model.selectedAgent == .llmChatPersonas {
                PersonaInputView(persona: Binding(
                    get: { model.personaText },
                    set: { model.personaText = $0 }
                ))
                Divider()
            }

            // ── Goal input ────────────────────────────────────────────────
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
```

---

## `ErrorBannerView`

```swift
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
```

---

## `PersonaInputView`

```swift
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
```

---

## `GoalInputView`

```swift
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
```

---

## `ConfigurationSheet`

```swift
struct ConfigurationSheet: View {
    var model: DashboardModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("LLM Endpoint") {
                    TextField("Server URL", text: Binding(
                        get: { model.configServerURL },
                        set: { model.configServerURL = $0 }
                    ))
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel("Server URL")
                    .accessibilityHint("The base URL of your LLM server, e.g. http://localhost:1234")
                }

                Section("Model") {
                    TextField("Model name", text: Binding(
                        get: { model.configModelName },
                        set: { model.configModelName = $0 }
                    ))
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .accessibilityLabel("Model name")
                    .accessibilityHint("The model identifier string, e.g. lmstudio-community/qwen3-8b")
                }

                Section("API Key") {
                    SecureField("Optional API key", text: Binding(
                        get: { model.configAPIKey },
                        set: { model.configAPIKey = $0 }
                    ))
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
```

---

## Platform Conditionals Summary

| Conditional | Location | Purpose |
|-------------|----------|---------|
| `#if os(macOS)` | `AgentDashboardApp` | `.defaultSize(1100, 720)` |
| `#if os(visionOS)` | `AgentDashboardApp` | `.defaultSize(900, 680).windowStyle(.plain)` |
| `#if os(macOS)` | `SidebarView` | `.navigationSplitViewColumnWidth(min: 200, ideal: 260)` |
| `#if os(iOS)` | `AgentDetailView` | `.navigationBarTitleDisplayMode(.inline)` |
| `#if os(iOS)` | `ConfigurationSheet` | `.navigationBarTitleDisplayMode(.inline)` + Cancel toolbar item |
