import SwiftUI
import Supabase

struct ContentView: View {
    @State private var scoreBoard = ScoreBoardModel()
    @FocusState private var initialFocus: Bool
    
    private var supabase: SupabaseClient { SupabaseService.shared.client }
    
    private func syncSetScore() {
        Task {
            let payload = scoreBoard.createSetScore()
            do {
                try await supabase
                    .from("daily_sets")
                    .upsert(payload,
                            onConflict: "day",
                            returning: .minimal)
                    .execute()
                #if DEBUG
                print("[Supabase] ✅ daily_sets upsert OK")
                #endif
            } catch {
                #if DEBUG
                print("[Supabase] ❌ daily_sets upsert FAILED:", error)
                #endif
            }
        }
    }
    
    private func syncGlobalScore() {
        Task {
            let payload = scoreBoard.createGlobalScore()
            do {
                try await supabase
                    .from("daily_totals")
                    .upsert(payload,
                            onConflict: "day",
                            returning: .minimal)
                    .execute()
                #if DEBUG
                print("[Supabase] ✅ daily_totals upsert OK")
                #endif
            } catch {
                #if DEBUG
                print("[Supabase] ❌ daily_totals upsert FAILED:", error)
                #endif
            }
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
                syncSetScore()
                syncGlobalScore()
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
            testSupabaseConnection()
        }
    }
    
    private func testSupabaseConnection() {
        Task {
            do {
                let _ = try await SupabaseService.shared.testConnection()
                await MainActor.run {
                    scoreBoard.updateConnectionStatus("OK", color: .green)
                }
            } catch {
                await MainActor.run {
                    let errorMsg = error.localizedDescription
                    let status = if errorMsg.contains("network") || errorMsg.contains("internet") {
                        "No Net"
                    } else if errorMsg.contains("unauthorized") || errorMsg.contains("auth") {
                        "Auth"
                    } else {
                        "Error"
                    }
                    scoreBoard.updateConnectionStatus(status, color: .red)
                }
                print("Supabase connection error: \(error)")
                print("Error type: \(type(of: error))")
            }
        }
    }
}

#Preview { ContentView() }