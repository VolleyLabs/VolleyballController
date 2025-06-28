import SwiftUI

struct TapZoneView: View {
    let color: Color
    let label: String
    let isLeft: Bool
    @Binding var score: Int
    @Binding var tapped: Bool
    @Binding var suppress: Bool
    
    let onScoreChange: () -> Void
    
    var body: some View {
        Button(action: {
            if suppress {
                suppress = false
            } else {
                adjustScore(by: 1)
            }
        }) {
            VStack {
                Text(label)
                    .font(.caption)
                Text("\(score)")
                    .font(.system(size: 60, weight: .bold))
            }
            .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .buttonStyle(.plain)
        .accessibilityLabel(Text(isLeft ? "Left score area" : "Right score area"))
        .accessibilityRespondsToUserInteraction(true)
        .accessibilityAddTraits(.isButton)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    adjustScore(by: -1)
                    suppress = true
                },
            including: .all
        )
    }
    
    private func adjustScore(by delta: Int) {
        let newValue = max(0, score + delta)
        guard newValue != score else { return }
        score = newValue
        onScoreChange()
        if isLeft {
            HapticService.shared.playLeftHaptic()
        } else {
            HapticService.shared.playRightHaptic()
        }
        flash()
    }
    
    private func flash() {
        tapped = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            tapped = false
        }
    }
}