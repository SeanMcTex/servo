import SwiftUI

struct PetView: View {
    var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                statusDot
                Text("Servo")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Text(appState.utterance)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
                .lineLimit(6)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 240, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
    }

    @ViewBuilder
    private var statusDot: some View {
        switch appState.status {
        case .idle:
            Circle().fill(.green).frame(width: 6, height: 6)
        case .thinking:
            Circle().fill(.yellow).frame(width: 6, height: 6)
        case .error:
            Circle().fill(.red).frame(width: 6, height: 6)
        }
    }
}

#Preview {
    let state = AppState()
    state.utterance = "The creature appears to be staring intently at lines of code. Fascinating."
    return PetView(appState: state).padding()
}
