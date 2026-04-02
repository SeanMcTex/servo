import SwiftUI

struct SettingsView: View {
    @Bindable var appState: AppState

    @State private var connectionStatus: ConnectionStatus = .untested
    @State private var isTesting = false

    enum ConnectionStatus {
        case untested, success([String]), failure(String)
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
            Section("Personality Prompt") {
                TextEditor(text: $appState.systemPrompt)
                    .font(.system(size: 12))
                    .frame(minHeight: 110)
                    .border(Color.secondary.opacity(0.3), width: 1)

                Button("Reset to Default") {
                    appState.systemPrompt = AppState.defaultPrompt
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.system(size: 11))
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
