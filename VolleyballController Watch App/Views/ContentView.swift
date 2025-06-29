import SwiftUI
import Supabase
import WatchKit

struct ContentView: View {
    @State private var scoreBoard = ScoreBoardModel()
    @FocusState private var initialFocus: Bool
    
    private var finishDisabled: Bool {
        scoreBoard.isLoading || abs(scoreBoard.leftScore - scoreBoard.rightScore) < 2 || scoreBoard.connectionStatus == "Error" || (scoreBoard.leftScore == 0 && scoreBoard.rightScore == 0)
    }
    
    private var resetDisabled: Bool {
        scoreBoard.isLoading || scoreBoard.connectionStatus == "Error" || (scoreBoard.leftScore == 0 && scoreBoard.rightScore == 0 && scoreBoard.leftWins == 0 && scoreBoard.rightWins == 0)
    }
    
    
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
                    isLoading: scoreBoard.isLoading,
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
                    isLoading: scoreBoard.isLoading,
                    onScoreChange: syncSetScore
                )
            }
            .onAppear {
                initialFocus = true
            }

            
            VStack {
                HStack(spacing: 8) {
                    Button("Finish") {
                        scoreBoard.finishSet()
                        syncSetScore()
                        syncGlobalScore()
                    }
                    .font(.caption2)
                    .buttonStyle(.borderless)
                    .focusable(false)
                    .disabled(finishDisabled)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(finishDisabled ? Color.gray.opacity(0.02) : Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 8))
                    
                    Button("Reset") {
                        scoreBoard.resetAll()
                        syncGlobalScore()
                        syncSetScore()
                    }
                    .font(.caption2)
                    .buttonStyle(.borderless)
                    .focusable(false)
                    .disabled(resetDisabled)
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(finishDisabled ? Color.gray.opacity(0.02) : Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 8))
                }
                Spacer()
            }
            
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 2) {
                    if scoreBoard.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                            .scaleEffect(0.6)
                            .frame(height: 12)
                    } else {
                        Text("\(scoreBoard.leftWins) – \(scoreBoard.rightWins)")
                            .font(.caption2)
                    }
                    HStack(spacing: 4) {
                        Circle()
                            .fill(scoreBoard.connectionColor)
                            .frame(width: 6, height: 6)
                        Text(scoreBoard.connectionStatus)
                            .font(.system(size: 8))
                    }
                }
                .padding(.bottom, -WKInterfaceDevice.current().screenBounds.height * 0.5)
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
        // Load data in background without blocking UI
        Task(priority: .userInitiated) {
            let success = await scoreBoard.loadInitialState()
            
            // Handle UI updates on main thread
            if success {
                scoreBoard.updateConnectionStatus("OK", color: .green)
            } else {
                scoreBoard.updateConnectionStatus("Error", color: .red)
            }
        }
    }
}

#Preview { ContentView() }
