import AppKit
import SwiftUI

final class FloatingPetPanel: NSPanel, NSWindowDelegate {

    private static let frameOriginKey = "petPanelOrigin"
    private weak var appState: AppState?

    init(appState: AppState) {
        let defaultRect = CGRect(x: 40, y: 40, width: 440, height: 220)
        // If a saved rect exists but was from the old small design, use the new default
        let saved = FloatingPetPanel.savedRect()
        let savedRect = (saved.map { $0.height > 150 } == true) ? saved! : defaultRect

        super.init(
            contentRect: savedRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        self.appState = appState

        isFloatingPanel = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false  // PetView draws its own shadow
        level = .floating
        delegate = self

        let hostingView = NSHostingView(rootView: PetView(appState: appState))
        hostingView.frame = CGRect(origin: .zero, size: savedRect.size)
        hostingView.autoresizingMask = [.width, .height]
        contentView = hostingView

        appState.panelFrame = savedRect
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        FloatingPetPanel.saveOrigin(frame.origin)
        appState?.panelFrame = frame
    }

    // MARK: - UserDefaults persistence

    private static func savedRect() -> CGRect? {
        guard let dict = UserDefaults.standard.dictionary(forKey: frameOriginKey),
              let x = dict["x"] as? Double,
              let y = dict["y"] as? Double
        else { return nil }
        return CGRect(x: x, y: y, width: 440, height: 220)
    }

    private static func saveOrigin(_ origin: CGPoint) {
        UserDefaults.standard.set(["x": origin.x, "y": origin.y], forKey: frameOriginKey)
    }
}
