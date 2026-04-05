import AppKit
import SwiftUI

final class PetIconPanel: NSPanel, NSWindowDelegate {

    private static let savedOriginKey = "petIconPanelOrigin"
    private static let legacyOriginKey = "petPanelOrigin"  // FloatingPetPanel's old key

    static let size = CGSize(width: 80, height: 80)

    /// Called whenever the panel moves. AppDelegate uses this to reposition the balloon.
    var onMove: (() -> Void)?

    init(appState: AppState) {
        let origin = PetIconPanel.savedOrigin()
        let rect = CGRect(origin: origin, size: Self.size)

        super.init(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isMovableByWindowBackground = true
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false
        level = .floating
        delegate = self

        let hosting = NSHostingView(rootView: PetIconView(appState: appState))
        hosting.frame = CGRect(origin: .zero, size: Self.size)
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting
    }

    // MARK: - NSWindowDelegate

    func windowDidMove(_ notification: Notification) {
        PetIconPanel.saveOrigin(frame.origin)
        onMove?()
    }

    // MARK: - Persistence

    private static func savedOrigin() -> CGPoint {
        let d = UserDefaults.standard
        var candidate: CGPoint?

        for key in [savedOriginKey, legacyOriginKey] {
            if let dict = d.dictionary(forKey: key),
               let x = dict["x"] as? Double,
               let y = dict["y"] as? Double {
                if key == legacyOriginKey {
                    d.set(["x": x, "y": y], forKey: savedOriginKey)
                }
                candidate = CGPoint(x: x, y: y)
                break
            }
        }

        let panelSize = PetIconPanel.size
        let fallback = CGPoint(x: 40, y: 40)
        let origin = candidate ?? fallback

        // Clamp to the nearest screen's visible frame so the panel is always on screen
        let panelRect = CGRect(origin: origin, size: panelSize)
        let screen = NSScreen.screens.first { $0.frame.intersects(panelRect) }
                  ?? NSScreen.main
        guard let screen else { return fallback }

        let visible = screen.visibleFrame
        let clampedX = max(visible.minX, min(visible.maxX - panelSize.width,  origin.x))
        let clampedY = max(visible.minY, min(visible.maxY - panelSize.height, origin.y))
        return CGPoint(x: clampedX, y: clampedY)
    }

    private static func saveOrigin(_ origin: CGPoint) {
        UserDefaults.standard.set(["x": origin.x, "y": origin.y], forKey: savedOriginKey)
    }
}
