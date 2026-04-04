import SwiftUI

struct PetView: View {
    var appState: AppState

    @State private var displayedText: String = ""
    @State private var bubbleOpacity: Double = 0
    @State private var bubbleScale: CGFloat = 0.85
    @State private var hideTask: Task<Void, Never>?
    @State private var bubbleHOffset: CGFloat = 0
    @State private var pulseScale: CGFloat = 1.0

    // Half of the bubble's maxWidth (210 / 2)
    private let bubbleHalfWidth: CGFloat = 105
    // Tail can shift at most this far from centre before overlapping a rounded corner:
    // bubbleHalfWidth − cornerRadius(14) − tailHalfWidth(8) = 83
    private let maxTailShift: CGFloat = 83

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            // Speech bubble — always in the layout; opacity/scale animate in and out
            VStack(alignment: .center, spacing: 0) {
                Text(displayedText)
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

                // Tail stays pinned over the character even when the box shifts sideways.
                // Its offset is the inverse of the box's offset, clamped to stay clear of corners.
                BubbleTail()
                    .fill(.white)
                    .frame(width: 16, height: 10)
                    .offset(x: max(-maxTailShift, min(maxTailShift, -bubbleHOffset)))
            }
            .shadow(color: .black.opacity(0.18), radius: 8, x: 0, y: 3)
            .opacity(bubbleOpacity)
            .scaleEffect(bubbleScale, anchor: .bottom)
            .offset(x: bubbleHOffset)

            Spacer().frame(height: 6)

            // Character portrait — pulses gently while the model is thinking
            Text(character)
                .font(.system(size: 44))
                .scaleEffect(pulseScale)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
        .padding(.top, 12)
        .onAppear {
            updateBubbleOffset(panelFrame: appState.panelFrame)
            animateIn(text: greeting)
        }
        .onChange(of: appState.panelFrame) { _, frame in
            updateBubbleOffset(panelFrame: frame)
        }
        .onChange(of: appState.utterance) { _, text in
            guard text != "Watching…" else { return }
            animateIn(text: text)
        }
        .onChange(of: appState.status) { _, status in
            if status == .thinking {
                withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                    pulseScale = 1.13
                }
            } else {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    pulseScale = 1.0
                }
            }
        }
    }

    // MARK: - Screen-edge adaptation

    private func updateBubbleOffset(panelFrame: CGRect) {
        guard panelFrame != .zero else { return }
        // panelFrame is in NSWindow / NSScreen coordinates (y-up, origin at bottom-left of
        // main screen). X is consistent across all screens: positive rightward from main origin.
        guard let screen = NSScreen.screens.first(where: {
            $0.frame.intersects(panelFrame)
        }) ?? NSScreen.main else { return }

        // Use screen.frame (not visibleFrame) for horizontal bounds so a side-positioned
        // Dock doesn't produce an offset large enough to clip the balloon against the panel edge.
        let minX = screen.frame.minX
        let maxX = screen.frame.maxX

        // Bubble is centred in the panel; maxWidth is 210.
        let bubbleCenterX = panelFrame.midX
        let naturalLeft  = bubbleCenterX - bubbleHalfWidth
        let naturalRight = bubbleCenterX + bubbleHalfWidth

        var offset: CGFloat = 0
        if naturalLeft < minX {
            offset = minX - naturalLeft
        } else if naturalRight > maxX {
            offset = maxX - naturalRight
        }

        // Cap at the smaller of: how far the bubble can move before hitting the panel edge,
        // and maxTailShift (83pt, the point where the tail would overlap a rounded corner).
        // The panel is 400pt wide so bubbleHalfWidth gives 95pt of room — maxTailShift wins.
        let maxShift = min(panelFrame.width / 2 - bubbleHalfWidth, maxTailShift)
        bubbleHOffset = max(-maxShift, min(maxShift, offset))
    }

    // MARK: - Personality

    private var character: String {
        switch appState.systemPrompt {
        case PersonalityPreset.all.first(where: { $0.id == "hal"            })?.prompt: return "🔴"
        case PersonalityPreset.all.first(where: { $0.id == "marvin"         })?.prompt: return "🤖"
        case PersonalityPreset.all.first(where: { $0.id == "companion"      })?.prompt: return "🐶"
        case PersonalityPreset.all.first(where: { $0.id == "tron"           })?.prompt: return "💠"
        case PersonalityPreset.all.first(where: { $0.id == "commentator"    })?.prompt: return "🎙️"
        case PersonalityPreset.all.first(where: { $0.id == "curse"          })?.prompt: return "💀"
        case PersonalityPreset.all.first(where: { $0.id == "parent"         })?.prompt: return "😔"
        case PersonalityPreset.all.first(where: { $0.id == "ships_computer" })?.prompt: return "🖖"
        case PersonalityPreset.all.first(where: { $0.id == "forecaster"     })?.prompt: return "🌦️"
        default:                                                                          return "👾"
        }
    }

    private var greeting: String {
        switch appState.systemPrompt {
        case PersonalityPreset.all.first(where: { $0.id == "hal"            })?.prompt: return "Good morning, Dave. I'm ready."
        case PersonalityPreset.all.first(where: { $0.id == "marvin"         })?.prompt: return "Oh. It's on again. Wonderful."
        case PersonalityPreset.all.first(where: { $0.id == "companion"      })?.prompt: return "Oh! Are we starting? WE'RE STARTING!"
        case PersonalityPreset.all.first(where: { $0.id == "tron"           })?.prompt: return "System online. User detected. Cycles resuming."
        case PersonalityPreset.all.first(where: { $0.id == "commentator"    })?.prompt: return "AND WE'RE LIVE! The User is at the controls!"
        case PersonalityPreset.all.first(where: { $0.id == "curse"          })?.prompt: return "You have returned. I have been waiting."
        case PersonalityPreset.all.first(where: { $0.id == "parent"         })?.prompt: return "Oh, you're on again. I hope you have a plan today."
        case PersonalityPreset.all.first(where: { $0.id == "ships_computer" })?.prompt: return "Systems online. Crew activity detected."
        case PersonalityPreset.all.first(where: { $0.id == "forecaster"     })?.prompt: return "Initializing. Conditions uncertain. Outlook: variable."
        default: return "Ah. The specimen activates once more."
        }
    }

    // MARK: - Animation

    private func animateIn(text: String) {
        hideTask?.cancel()
        displayedText = text

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
        }
    }
}

// MARK: - Bubble tail shape

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
    PetView(appState: AppState())
        .background(.gray.opacity(0.3))
}
