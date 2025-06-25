import SwiftUI
import WatchKit          // haptic feedback

struct ContentView: View {
    // Per-set score
    @State private var leftScore  = 0
    @State private var rightScore = 0
    // Crown delta accumulators
    @State private var crownLeft  = 0.0
    @State private var crownRight = 0.0
    // Match totals (“global score”)
    @State private var leftWins   = 0
    @State private var rightWins  = 0
    // Tap-flash state
    @State private var leftTapped  = false
    @State private var rightTapped = false
    // Suppress button tap after a long‑press (per side)
    @State private var suppressLeftTap  = false
    @State private var suppressRightTap = false
    // Supabase connection test
    @State private var connectionStatus: String = "Connecting..."
    @State private var connectionColor: Color = .orange
    
    @FocusState private var initialFocus: Bool

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
                        crown: $crownLeft,
                        suppress: $suppressLeftTap,
                        label: "LEFT")
                .focused($initialFocus)

                tapZone(color: .red,
                        score: $rightScore,
                        tapped: $rightTapped,
                        crown: $crownRight,
                        suppress: $suppressRightTap,
                        label: "RIGHT")
            }
            .onAppear {
                // give the runloop a tick so layout is done
                DispatchQueue.main.async { initialFocus = true }
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
            .focusable(false)        // keep tap gesture but remove from Digital Crown focus
            .accessibilityHidden(true) // also hide from accessibility focus engine
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
                    .focusable(false)   // prevent Digital Crown from selecting this button
                    .padding(.trailing, 4)
                }
                .overlay(
                    VStack(spacing: 2) {
                        Text("\(leftWins) – \(rightWins)")
                            .font(.caption2)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(connectionColor)
                                .frame(width: 6, height: 6)
                            Text(connectionStatus)
                                .font(.system(size: 8))
                        }
                    },
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
        .onAppear {
            testSupabaseConnection()
        }
    }
    
    private func testSupabaseConnection() {
        Task {
            do {
                let _ = try await SupabaseService.shared.testConnection()
                await MainActor.run {
                    connectionStatus = "OK"
                    connectionColor = .green
                }
            } catch {
                await MainActor.run {
                    // Show more specific error info
                    let errorMsg = error.localizedDescription
                    if errorMsg.contains("network") || errorMsg.contains("internet") {
                        connectionStatus = "No Net"
                    } else if errorMsg.contains("unauthorized") || errorMsg.contains("auth") {
                        connectionStatus = "Auth"
                    } else {
                        connectionStatus = "Error"
                    }
                    connectionColor = .red
                }
                print("Supabase connection error: \(error)")
                print("Error type: \(type(of: error))")
            }
        }
    }

    /// One half of the screen with flashing feedback
    private func tapZone(color: Color,
                         score: Binding<Int>,
                         tapped: Binding<Bool>,
                         crown: Binding<Double>,
                         suppress: Binding<Bool>,
                         label: String) -> some View {
        // Helper ­– flash overlay for 0.2 s
        func flash() {
            tapped.wrappedValue = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                tapped.wrappedValue = false
            }
        }
        // Helper ­– adjust score and play feedback
        func adjust(by delta: Int) {
            let newValue = max(0, score.wrappedValue + delta)
            guard newValue != score.wrappedValue else { return }
            score.wrappedValue = newValue
            (label == "LEFT" ? playLeftHaptic() : playRightHaptic())
            flash()
        }

        return Button(action: {
            if suppress.wrappedValue {
                suppress.wrappedValue = false     // consume suppressed tap
            } else {
                adjust(by: +1)
            }
        }) {
            ZStack {
                // Flash overlay
                color.opacity(tapped.wrappedValue ? 0.2 : 0)
                    .animation(.easeOut(duration: 0.2), value: tapped.wrappedValue)

                // Hit area (invisible)
                Color.clear
                    .contentShape(Rectangle())
                    // Digital Crown ±1
                    .focusable(true)
                    .digitalCrownRotation(crown,
                                          from: -10, through: 10, by: 1,
                                          sensitivity: .medium,
                                          isContinuous: false)
                    .onChange(of: crown.wrappedValue) { _, newVal in
                        if newVal > 0 { adjust(by: +1) }
                        else if newVal < 0 { adjust(by: -1) }
                        crown.wrappedValue = 0      // reset
                    }
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)   // makes AssistiveTouch focusable
        .buttonStyle(.plain)        // invisible
        .accessibilityLabel(Text(label == "LEFT" ? "Left score area" : "Right score area"))
        .accessibilityRespondsToUserInteraction(true)
        .accessibilityAddTraits(.isButton)
        // Long‑press (–1)
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    adjust(by: -1)
                    suppress.wrappedValue = true   // prevent following tap
                },
            including: .all)
    }

    // MARK: – Haptic helpers
    private func playLeftHaptic()  { WKInterfaceDevice.current().play(.directionUp) }  // audible up‑tone
    private func playRightHaptic() { WKInterfaceDevice.current().play(.success) }      // audible chime
}

#Preview { ContentView() }
