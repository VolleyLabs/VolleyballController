import SwiftUI

struct TapZoneView: View {
    let color: Color
    let label: String
    let isLeft: Bool
    @Binding var score: Int
    @Binding var tapped: Bool
    @Binding var suppress: Bool
    let isLoading: Bool
    
    let onScoreChange: () -> Void
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: color))
                    .scaleEffect(1.5)
                    .frame(width: 80, height: 80)
            } else {
                Text("\(score)")
                    .font(.system(size: 80, weight: .bold))
            }
        }
        .foregroundColor(color)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .accessibilityLabel(Text(isLeft ? "Left score area" : "Right score area"))
        .accessibilityRespondsToUserInteraction(true)
        .accessibilityAddTraits(.isButton)
        .onTapGesture {
            if !suppress {
                adjustScore(by: 1)
            } else {
                suppress = false
            }
        }
        .onLongPressGesture(minimumDuration: 0.5) {
            adjustScore(by: -1)
            suppress = true
        }
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