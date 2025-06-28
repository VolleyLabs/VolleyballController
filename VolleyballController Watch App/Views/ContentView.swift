import SwiftUI
import Supabase

struct ContentView: View {
    @State private var scoreBoard = ScoreBoardModel()
    @FocusState private var initialFocus: Bool
    
    
    private func syncSetScore() {
        Task {
            let payload = scoreBoard.createSetScore()
            try? await SupabaseService.shared.syncSetScore(payload)
        }
    }
    
    private func syncGlobalScore() {
        Task {
            let payload = scoreBoard.createGlobalScore()
            try? await SupabaseService.shared.syncGlobalScore(payload)
        }
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                TapZoneView(
                    color: .blue,
                    label: "LEFT",
                    isLeft: true,
                    score: $scoreBoard.leftScore,
                    tapped: $scoreBoard.leftTapped,
                    suppress: $scoreBoard.suppressLeftTap,
                    onScoreChange: syncSetScore
                )
                .focused($initialFocus)
                
                TapZoneView(
                    color: .red,
                    label: "RIGHT",
                    isLeft: false,
                    score: $scoreBoard.rightScore,
                    tapped: $scoreBoard.rightTapped,
                    suppress: $scoreBoard.suppressRightTap,
                    onScoreChange: syncSetScore
                )
            }
            .onAppear {
                DispatchQueue.main.async { initialFocus = true }
            }

            .safeAreaInset(edge: .bottom) {
                Button("Finish") {
                    scoreBoard.finishSet()
                    syncSetScore()
                    syncGlobalScore()
                }
                .font(.footnote)
                .buttonStyle(.borderless)
                .padding(.bottom, 2)
                .focusable(false)
                .accessibilityHidden(true)
            }

            VStack {
                ScoreDisplayView(
                    leftWins: scoreBoard.leftWins,
                    rightWins: scoreBoard.rightWins,
                    connectionStatus: scoreBoard.connectionStatus,
                    connectionColor: scoreBoard.connectionColor,
                    onReset: {
                        scoreBoard.resetAll()
                        syncGlobalScore()
                        syncSetScore()
                    }
                )
                Spacer()
            }
        }
        .overlay(
            HStack(spacing: 0) {
                Color(scoreBoard.leftTapped ? .blue : .clear)
                    .opacity(scoreBoard.leftTapped ? 0.2 : 0)
                    .animation(.easeOut(duration: 0.2), value: scoreBoard.leftTapped)
                Color(scoreBoard.rightTapped ? .red : .clear)
                    .opacity(scoreBoard.rightTapped ? 0.2 : 0)
                    .animation(.easeOut(duration: 0.2), value: scoreBoard.rightTapped)
            }
            .allowsHitTesting(false)
            .ignoresSafeArea()
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            initializeApp()
        }
    }
    
    private func initializeApp() {
        Task {
            // Show connecting state briefly so user can see it
            await MainActor.run {
                scoreBoard.updateConnectionStatus("Connecting...", color: .orange)
            }
            
            // Load initial state (this also tests connection)
            let success = await scoreBoard.loadInitialState()
            
            await MainActor.run {
                if success {
                    // Connection successful
                    scoreBoard.updateConnectionStatus("OK", color: .green)
                } else {
                    // Connection failed - show appropriate error status
                    scoreBoard.updateConnectionStatus("Error", color: .red)
                }
            }
            
        }
    }
}

#Preview { ContentView() }