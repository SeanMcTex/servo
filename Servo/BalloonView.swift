import SwiftUI

// MARK: - TailSide

enum TailSide {
    case up    // balloon is below the icon — tail points up toward it
    case down  // balloon is above the icon — tail points down toward it
}

// MARK: - BalloonPanelState

@Observable
final class BalloonPanelState {
    var text: String = ""
    var tailSide: TailSide = .down
    var tailHOffset: CGFloat = 0
    /// Incrementing this triggers animateIn() via onChange in BalloonView.
    /// Using a counter (vs. a Bool) ensures repeated shows of the same text still fire.
    var showTrigger: Int = 0
}

// MARK: - BalloonView

struct BalloonView: View {
    var appState: AppState
    var state: BalloonPanelState
    /// Called when a new utterance arrives; the panel repositions itself then updates state.
    var requestShow: (String) -> Void
    /// Called after the fade-out completes so the panel can orderOut.
    var requestHide: () -> Void

    @State private var bubbleOpacity: Double = 0
    @State private var bubbleScale: CGFloat = 0.85
    @State private var hideTask: Task<Void, Never>?

    private let maxTailShift: CGFloat = 83

    var body: some View {
        bubbleAndTail
            // Align content to the tail edge so it sits flush against the icon panel
            .frame(width: 280, height: 150, alignment: state.tailSide == .up ? .top : .bottom)
            .onChange(of: appState.utterance) { _, text in
                guard text != "Watching…" else { return }
                requestShow(text)
            }
            .onChange(of: state.showTrigger) { _, _ in
                animateIn()
            }
    }

    // MARK: - Bubble + tail

    @ViewBuilder
    private var bubbleAndTail: some View {
        let tailOffset = max(-maxTailShift, min(maxTailShift, state.tailHOffset))

        VStack(alignment: .center, spacing: 0) {
            if state.tailSide == .up {
                // Inverted tail points up toward icon above
                BubbleTail()
                    .fill(.white)
                    .frame(width: 16, height: 10)
                    .scaleEffect(y: -1)
                    .offset(x: tailOffset)
            }

            Text(state.text)
                .font(.system(size: 13))
                .foregroundStyle(.black)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: 210)
                .background {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(.white)
                }

            if state.tailSide == .down {
                // Normal tail points down toward icon below
                BubbleTail()
                    .fill(.white)
                    .frame(width: 16, height: 10)
                    .offset(x: tailOffset)
            }
        }
        .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 3)
        .opacity(bubbleOpacity)
        .scaleEffect(bubbleScale, anchor: state.tailSide == .up ? .top : .bottom)
    }

    // MARK: - Animation

    private func animateIn() {
        hideTask?.cancel()
        // Snap to initial state so rapid successive shows always animate in cleanly
        bubbleOpacity = 0
        bubbleScale = 0.85
        withAnimation(.spring(response: 0.4, dampingFraction: 0.65)) {
            bubbleOpacity = 1
            bubbleScale = 1
        }
        hideTask = Task {
            try? await Task.sleep(for: .seconds(10))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.5)) {
                bubbleOpacity = 0
                bubbleScale = 0.85
            }
            // Wait for fade-out to complete before removing the panel
            try? await Task.sleep(for: .seconds(0.6))
            guard !Task.isCancelled else { return }
            requestHide()
        }
    }
}

// MARK: - BubbleTail shape

struct BubbleTail: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.closeSubpath()
        }
    }
}

#Preview {
    let state = BalloonPanelState()
    let _ = { state.text = "Hello from the preview!"; state.tailSide = .down; state.showTrigger = 1 }()
    return BalloonView(
        appState: AppState(),
        state: state,
        requestShow: { _ in },
        requestHide: {}
    )
    .background(.gray.opacity(0.3))
}
