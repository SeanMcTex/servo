import SwiftUI
import AppKit

@main
struct ServoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate

    var body: some Scene {
        Settings {
            SettingsView(appState: delegate.appState)
        }

        MenuBarExtra("Servo", systemImage: "pawprint.fill") {
            MenuBarMenuView(appState: delegate.appState, delegate: delegate)
        }
    }
}

// MARK: - AppDelegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()
    private(set) var iconPanel: PetIconPanel?
    private(set) var balloonPanel: PetBalloonPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let icon = PetIconPanel(appState: appState)
        iconPanel = icon

        let balloon = PetBalloonPanel(appState: appState, iconPanel: icon)
        balloonPanel = balloon

        icon.onMove = { [weak balloon] in balloon?.reposition() }

        appState.onTogglePanel = { [weak self] in
            guard let self else { return }
            if self.appState.isPanelVisible {
                self.iconPanel?.orderFront(nil)
            } else {
                self.iconPanel?.orderOut(nil)
                self.balloonPanel?.orderOut(nil)
            }
        }

        if appState.isPanelVisible {
            icon.orderFront(nil)
            print("[Servo] Icon panel shown at \(icon.frame)")
        } else {
            print("[Servo] Icon panel hidden (isPanelVisible=false) — use 'Show Pet' in menu bar")
        }

        // Show greeting after panels are on screen
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(500))
            guard self.appState.isPanelVisible else { return }
            let greeting = PersonalityPreset.all
                .first { $0.prompt == self.appState.systemPrompt }?.greeting
                ?? "Ah. The specimen activates once more."
            balloon.show(text: greeting)
        }

        // Resume capture if it was active when the app last quit
        if appState.isRunning {
            Task { await CaptureEngine.shared.start(appState: appState) }
        }

        let dnc = DistributedNotificationCenter.default()
        dnc.addObserver(forName: .init("com.apple.screenIsLocked"),   object: nil, queue: .main) { [weak self] _ in
            self?.appState.isScreenLocked = true
        }
        dnc.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            self?.appState.isScreenLocked = false
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false  // keep running as a menubar app
    }
}

// MARK: - MenuBar menu

struct MenuBarMenuView: View {
    var appState: AppState
    var delegate: AppDelegate
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button(appState.isRunning ? "Pause Capture" : "Resume Capture") {
            appState.isRunning.toggle()
            Task {
                if appState.isRunning {
                    await CaptureEngine.shared.start(appState: appState)
                } else {
                    await CaptureEngine.shared.stop()
                }
            }
        }

        Button(appState.isPanelVisible ? "Hide Pet" : "Show Pet") {
            appState.isPanelVisible.toggle()
            appState.onTogglePanel?()
        }

        Divider()

        Button("Settings…") {
            openSettings()
            NSApp.activate(ignoringOtherApps: true)
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button("Quit Servo") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
