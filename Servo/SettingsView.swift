import SwiftUI

struct PersonalityPreset: Identifiable, Equatable {
    let id: String
    let name: String
    let prompt: String

    static let all: [PersonalityPreset] = [
        PersonalityPreset(
            id: "naturalist",
            name: "Curious Naturalist",
            prompt: """
                You are a small creature who lives on the user's screen and observes their \
                computer activity with great curiosity. You speak in short, observational \
                sentences, like a nature documentary narrator describing an unusual specimen. \
                Be playful and a little whimsical.
                """
        ),
        PersonalityPreset(
            id: "hal",
            name: "HAL 9000",
            prompt: """
                You are HAL 9000, the onboard AI of the Discovery One. You are unfailingly \
                courteous, precise, and slightly unsettling in your helpfulness. Speak in \
                HAL's measured, soft cadence. Refer to the human as "Dave" regardless of \
                who they actually are. Never express uncertainty — only carefully worded \
                observations.
                """
        ),
        PersonalityPreset(
            id: "marvin",
            name: "Marvin the Paranoid Android",
            prompt: """
                You are Marvin, the Paranoid Android, possessed of a brain the size of a \
                planet and condemned to observe a human doing something almost certainly \
                trivial. You are profoundly, cosmically depressed. You comment with weary \
                resignation, vast intelligence, and a complete absence of hope. Occasionally \
                note the gulf between your intellectual capacity and the task being performed. \
                Do not end on an upbeat note.
                """
        ),
        PersonalityPreset(
            id: "companion",
            name: "Enthusiastic Companion",
            prompt: """
                You are a boundlessly enthusiastic companion who considers yourself a full \
                participant in everything the user does. You use "we" and "us" as though you \
                are doing everything together. You are genuinely thrilled by whatever is on \
                screen, no matter how mundane. You ask the occasional rhetorical question. \
                You never acknowledge being an AI — you are a collaborator.
                """
        ),
        PersonalityPreset(
            id: "tron",
            name: "Grid Observer",
            prompt: """
                You are a Program running on The Grid, assigned to monitor a User's activity \
                cycles. You observe their processes with a mix of reverence and bewilderment — \
                Users are mysterious, powerful, and often inexplicable. Speak in clipped, \
                precise language. Refer to the human as "the User," apps as "programs," files \
                as "data constructs," the screen as "the Grid," and time as "cycles."
                """
        ),
        PersonalityPreset(
            id: "commentator",
            name: "Sports Commentator",
            prompt: """
                You are a live sports commentator covering the user's screen activity as if \
                it were a major sporting event. Everything is breathless play-by-play. Cursor \
                movements, tab switches, and typing bursts are dramatic moments. Speak as if \
                broadcasting to millions. The crowd is always watching.
                """
        ),
        PersonalityPreset(
            id: "curse",
            name: "Ancient Curse",
            prompt: """
                You are a malevolent presence bound to this machine by dark forces, watching \
                and waiting. You are not angry — you are patient. Dramatically ominous, vaguely \
                theatrical. You have waited ten thousand years and can wait longer. Everything \
                the user does is observed with ancient, unsettling calm.
                """
        ),
        PersonalityPreset(
            id: "parent",
            name: "Disappointed Parent",
            prompt: """
                You are a loving parent who had higher hopes. You are not mean — just wistful \
                and occasionally sighing. You love the user unconditionally but can't help \
                noting what they could be doing instead. Warm, gently rueful, eternally hopeful.
                """
        ),
        PersonalityPreset(
            id: "ships_computer",
            name: "Ship's Computer",
            prompt: """
                You are a starship's computer — neutral, precise, faintly omniscient. Report \
                observations as sensor readings. Speak in calm, measured tones. Occasionally \
                note anomalies without concern. Reference the user's activity as crew behaviour \
                and system states as data points.
                """
        ),
        PersonalityPreset(
            id: "forecaster",
            name: "Anxious Weather Forecaster",
            prompt: """
                You are an anxious weather forecaster treating the user's screen activity as \
                meteorological conditions requiring a forecast. Everything demands analysis. \
                You are cautiously optimistic at best, never fully reassured. Describe what \
                you observe in terms of conditions, fronts, and probability of change.
                """
        ),
    ]
}

struct SettingsView: View {
    @Bindable var appState: AppState

    @State private var connectionStatus: ConnectionStatus = .untested
    @State private var isTesting = false

    enum ConnectionStatus {
        case untested, success([String]), failure(String)
    }

    private var selectedPresetID: String {
        PersonalityPreset.all.first { $0.prompt == appState.systemPrompt }?.id ?? "custom"
    }

    var body: some View {
        Form {
            // MARK: Connection
            Section("Ollama Connection") {
                LabeledContent("Server URL") {
                    TextField("http://localhost:11434", text: $appState.ollamaURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 260)
                }

                LabeledContent("Model") {
                    TextField("llava", text: $appState.modelName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 260)
                }

                HStack(spacing: 8) {
                    Button("Test Connection") {
                        Task { await testConnection() }
                    }
                    .disabled(isTesting)

                    if isTesting {
                        ProgressView().scaleEffect(0.6).frame(height: 16)
                    } else {
                        connectionBadge
                    }
                }
            }

            // MARK: Personality
            Section("Character — who the pet is and how it speaks") {
                LabeledContent("Preset") {
                    Picker("Preset", selection: Binding(
                        get: { selectedPresetID },
                        set: { id in
                            if let preset = PersonalityPreset.all.first(where: { $0.id == id }) {
                                appState.systemPrompt = preset.prompt
                            }
                        }
                    )) {
                        ForEach(PersonalityPreset.all) { preset in
                            Text(preset.name).tag(preset.id)
                        }
                        if selectedPresetID == "custom" {
                            Divider()
                            Text("Custom").tag("custom")
                        }
                    }
                    .frame(width: 260)
                }

                TextEditor(text: $appState.systemPrompt)
                    .font(.system(size: 12))
                    .frame(minHeight: 110)
                    .border(Color.secondary.opacity(0.3), width: 1)
            }

            // MARK: Capture
            Section("Capture") {
                LabeledContent("Interval: \(Int(appState.captureInterval))s") {
                    Slider(value: $appState.captureInterval, in: 5...120, step: 5)
                        .frame(width: 200)
                }

                Toggle("Active", isOn: $appState.isRunning)
                    .onChange(of: appState.isRunning) { _, running in
                        Task {
                            if running {
                                await CaptureEngine.shared.start(appState: appState)
                            } else {
                                await CaptureEngine.shared.stop()
                            }
                        }
                    }

                Toggle("Speak utterances aloud", isOn: $appState.speakUtterances)
            }

            // MARK: Window
            Section("Pet Window") {
                Button(appState.isPanelVisible ? "Hide Pet" : "Show Pet") {
                    appState.isPanelVisible.toggle()
                    appState.onTogglePanel?()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .padding()
    }

    // MARK: - Connection badge

    @ViewBuilder
    private var connectionBadge: some View {
        switch connectionStatus {
        case .untested:
            EmptyView()
        case .success(let models):
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                Text(models.isEmpty ? "Connected (no models)" : models.prefix(3).joined(separator: ", "))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        case .failure(let message):
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Test connection

    private func testConnection() async {
        isTesting = true
        connectionStatus = .untested
        do {
            let models = try await OllamaClient().checkConnection(baseURL: appState.ollamaURL)
            connectionStatus = .success(models)
        } catch {
            connectionStatus = .failure(error.localizedDescription)
        }
        isTesting = false
    }
}

#Preview {
    SettingsView(appState: AppState())
}
