import SwiftUI

struct PetIconView: View {
    var appState: AppState

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        Text(character)
            .font(.system(size: 44))
            .scaleEffect(pulseScale)
            .frame(width: 80, height: 80)
            .background(.clear)
            .contentShape(Rectangle())
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

    private var character: String {
        PersonalityPreset.all.first { $0.prompt == appState.systemPrompt }?.emoji ?? "👾"
    }
}

#Preview {
    PetIconView(appState: AppState())
        .background(.gray.opacity(0.3))
}
