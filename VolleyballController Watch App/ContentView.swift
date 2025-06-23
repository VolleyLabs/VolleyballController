import SwiftUI

struct ContentView: View {
    // Per-set score
    @State private var leftScore  = 0
    @State private var rightScore = 0
    // Match totals (“global score”)
    @State private var leftWins   = 0
    @State private var rightWins  = 0
    // Tap-flash state
    @State private var leftTapped  = false
    @State private var rightTapped = false

    /// “Left”, “Right”, or “Tie”
    private var winner: String {
        leftScore == rightScore ? "Tie"
        : (leftScore > rightScore ? "Left" : "Right")
    }

    var body: some View {
        ZStack {
            // Main two-zone tap area
            HStack(spacing: 0) {
                tapZone(color: .blue,
                        score: $leftScore,
                        tapped: $leftTapped,
                        label: "LEFT")

                tapZone(color: .red,
                        score: $rightScore,
                        tapped: $rightTapped,
                        label: "RIGHT")
            }

        // Finish button – smaller and pinned to bottom
        .safeAreaInset(edge: .bottom) {
            Button("Finish") {
                // Update global totals if not a tie
                if leftScore != rightScore {
                    if leftScore > rightScore { leftWins += 1 } else { rightWins += 1 }
                    leftScore = 0
                    rightScore = 0
                }
            }
            .font(.footnote)
            .buttonStyle(.borderless)
            .padding(.bottom, 2)
        }

            // Top bar — reset top‑right and global score top‑center
            VStack {
                HStack {
                    Spacer()
                    Button("Reset") {
                        leftWins = 0
                        rightWins = 0
                    }
                    .font(.caption2)
                    .buttonStyle(.borderless)
                    .padding(.trailing, 4)
                }
                .overlay(
                    Text("\(leftWins) – \(rightWins)")
                        .font(.caption2),
                    alignment: .center
                )

                Spacer()
            }
        }
        // Full‑height flash overlay for each half (covers Finish area too)
        .overlay(
            HStack(spacing: 0) {
                Color(leftTapped ? .blue : .clear)
                    .opacity(leftTapped ? 0.2 : 0)
                    .animation(.easeOut(duration: 0.2), value: leftTapped)
                Color(rightTapped ? .red : .clear)
                    .opacity(rightTapped ? 0.2 : 0)
                    .animation(.easeOut(duration: 0.2), value: rightTapped)
            }
            .allowsHitTesting(false)   // overlay shouldn’t block taps
            .ignoresSafeArea()         // extend under safe‑area insets
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// One half of the screen with flashing feedback
    private func tapZone(color: Color,
                         score: Binding<Int>,
                         tapped: Binding<Bool>,
                         label: String) -> some View {
        ZStack {
            // Flash overlay
            color.opacity(tapped.wrappedValue ? 0.2 : 0)
                .animation(.easeOut(duration: 0.2), value: tapped.wrappedValue)

            // Invisible hit area
            Color.clear
                .contentShape(Rectangle())
                // Increase on single tap
                .onTapGesture {
                    score.wrappedValue += 1
                    tapped.wrappedValue = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        tapped.wrappedValue = false
                    }
                }
                // Decrease on long‑press (0.5 s)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 0.5)
                        .onEnded { _ in
                            if score.wrappedValue > 0 {
                                score.wrappedValue -= 1
                                tapped.wrappedValue = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    tapped.wrappedValue = false
                                }
                            }
                        })
                // Score labels
                .overlay(
                    VStack {
                        Text(label).font(.caption)
                        Text("\(score.wrappedValue)")
                            .font(.system(size: 60, weight: .bold))
                    }
                    .foregroundColor(color)
                )
        }
    }
}

#Preview { ContentView() }
