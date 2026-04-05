import AppKit
import SwiftUI

final class PetBalloonPanel: NSPanel {

    private let state = BalloonPanelState()
    private static let balloonSize = CGSize(width: 280, height: 150)
    private weak var iconPanel: PetIconPanel?

    init(appState: AppState, iconPanel: PetIconPanel) {
        self.iconPanel = iconPanel

        super.init(
            contentRect: CGRect(origin: .zero, size: Self.balloonSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        isMovableByWindowBackground = false
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false  // BalloonView draws its own shadow
        level = .floating

        let balloonView = BalloonView(
            appState: appState,
            state: state,
            requestShow: { [weak self] text in self?.show(text: text) },
            requestHide: { [weak self] in self?.orderOut(nil) }
        )
        let hosting = NSHostingView(rootView: balloonView)
        hosting.frame = CGRect(origin: .zero, size: Self.balloonSize)
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting
    }

    // MARK: - Reposition (called while balloon is visible and icon is being dragged)

    func reposition() {
        guard isVisible, let iconPanel, iconPanel.isVisible else { return }
        let (origin, tailSide, tailHOffset) = placement(iconFrame: iconPanel.frame)
        state.tailSide = tailSide
        state.tailHOffset = tailHOffset
        setFrameOrigin(origin)
    }

    // MARK: - Show

    func show(text: String) {
        guard let iconPanel, iconPanel.isVisible else { return }
        let (origin, tailSide, tailHOffset) = placement(iconFrame: iconPanel.frame)
        state.text = text
        state.tailSide = tailSide
        state.tailHOffset = tailHOffset
        state.showTrigger += 1
        setFrameOrigin(origin)
        orderFront(nil)
    }

    // MARK: - Placement

    /// Computes balloon origin, tail direction, and tail offset for a given icon frame.
    private func placement(iconFrame: CGRect) -> (origin: CGPoint, tailSide: TailSide, tailHOffset: CGFloat) {
        let balloonSize = Self.balloonSize
        let screen = NSScreen.screens.first { $0.frame.intersects(iconFrame) } ?? NSScreen.main!
        let visible = screen.visibleFrame

        // Vertical: prefer above, flip below if not enough room
        let tailSide: TailSide
        let balloonY: CGFloat
        if visible.maxY - iconFrame.maxY >= balloonSize.height {
            tailSide = .down
            balloonY = iconFrame.maxY           // balloon bottom = icon top
        } else {
            tailSide = .up
            balloonY = iconFrame.minY - balloonSize.height  // balloon top = icon bottom
        }

        // Horizontal: centred over icon, clamped to visible screen
        let idealX = iconFrame.midX - balloonSize.width / 2
        let balloonX = max(visible.minX, min(visible.maxX - balloonSize.width, idealX))

        // Tail offset: shift from balloon centre to point at icon centre
        let tailHOffset = iconFrame.midX - (balloonX + balloonSize.width / 2)

        return (CGPoint(x: balloonX, y: balloonY), tailSide, tailHOffset)
    }
}
