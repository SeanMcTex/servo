import Foundation
import Observation
import AVFoundation

enum ServoStatus: Equatable {
    case idle
    case thinking
    case error(String)
}

@Observable
final class AppState {

    // MARK: - Live state (not persisted)
    var utterance: String = "Watching…"
    var status: ServoStatus = .idle

    // MARK: - Persisted settings

    var isRunning: Bool = false {
        didSet { UserDefaults.standard.set(isRunning, forKey: "isRunning") }
    }

    var ollamaURL: String = "http://localhost:11434" {
        didSet { UserDefaults.standard.set(ollamaURL, forKey: "ollamaURL") }
    }

    var modelName: String = "llava" {
        didSet { UserDefaults.standard.set(modelName, forKey: "modelName") }
    }

    var systemPrompt: String = AppState.defaultPrompt {
        didSet { UserDefaults.standard.set(systemPrompt, forKey: "systemPrompt") }
    }

    var captureInterval: Double = 30 {
        didSet { UserDefaults.standard.set(captureInterval, forKey: "captureInterval") }
    }

    var isPanelVisible: Bool = true {
        didSet { UserDefaults.standard.set(isPanelVisible, forKey: "isPanelVisible") }
    }

    var speakUtterances: Bool = false {
        didSet { UserDefaults.standard.set(speakUtterances, forKey: "speakUtterances") }
    }

    // MARK: - Speech synthesis

    private let synthesizer = AVSpeechSynthesizer()

    func speakIfEnabled(_ text: String) {
        guard speakUtterances else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        synthesizer.speak(utterance)
    }

    // MARK: - Callbacks set by AppDelegate

    /// Called by AppDelegate; invoked by SettingsView to show/hide the floating panel.
    var onTogglePanel: (() -> Void)?

    // MARK: - Init

    init() {
        let d = UserDefaults.standard
        if let v = d.object(forKey: "isRunning") as? Bool { isRunning = v }
        if let v = d.string(forKey: "ollamaURL") { ollamaURL = v }
        if let v = d.string(forKey: "modelName") { modelName = v }
        if let v = d.string(forKey: "systemPrompt") { systemPrompt = v }
        if let v = d.object(forKey: "captureInterval") as? Double { captureInterval = v }
        if let v = d.object(forKey: "isPanelVisible") as? Bool { isPanelVisible = v }
        if let v = d.object(forKey: "speakUtterances") as? Bool { speakUtterances = v }
    }

    // MARK: - Default prompt

    static let defaultPrompt = """
        You are a small creature who lives on the user's screen and observes their \
        computer activity with great curiosity. You speak in short, observational \
        sentences, like a nature documentary narrator describing an unusual specimen. \
        Keep responses under 25 words. Be playful and a little whimsical.
        """
}
