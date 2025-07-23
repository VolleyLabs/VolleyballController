import SwiftUI

struct TapZoneView: View {
    let color: Color
    let label: String
    let isLeft: Bool
    @Binding var score: Int
    @Binding var tapped: Bool
    @Binding var suppress: Bool
    let isLoading: Bool
    let errorPercentage: Double?

    let onScoreAdjust: (Bool, Int, PointType?, String?) -> Void

    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: color))
                    .scaleEffect(1.5)
                    .frame(width: 80, height: 80)
            } else {
                VStack(spacing: 2) {
                    // Error percentage display
                    if let errorPercentage = errorPercentage, errorPercentage > 0 {
                        Text("\(errorPercentage, specifier: "%.1f")%")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(color.opacity(0.6))
                    }
                    
                    Text("\(score)")
                        .font(.system(size: 80, weight: .bold))
                }
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
        onScoreAdjust(isLeft, delta, nil, nil)
        flash()

        // Play haptic feedback only for negative adjustments (long press)
        // Positive adjustments will get haptic feedback after type selection
        if delta < 0 {
            HapticService.shared.playCancelHaptic()
        }
    }

    private func flash() {
        tapped = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            tapped = false
        }
    }
}
