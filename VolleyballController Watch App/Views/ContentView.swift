import SwiftUI
import Supabase
import WatchKit

struct ContentView: View {
    @State private var scoreBoard = ScoreBoardModel()
    @State private var showingMenu = false
    @State private var showingHistory = false
    @State private var showingTeamSelection = false
    @FocusState private var initialFocus: Bool
    //@StateObject private var watchConnectivity = WatchConnectivityService.shared

    private var resetDisabled: Bool {
        let isLoadingOrError = scoreBoard.isLoading || scoreBoard.connectionStatus == "Error"
        let allScoresZero = scoreBoard.leftScore == 0 && scoreBoard.rightScore == 0 &&
                           scoreBoard.leftWins == 0 && scoreBoard.rightWins == 0
        return isLoadingOrError || allScoresZero
    }

    private func handleScoreAdjust(isLeft: Bool, delta: Int, pointType: PointType?, player: String?) {
        scoreBoard.requestScoreAdjustment(isLeft: isLeft, delta: delta, playerId: nil)

        // Add haptic feedback
        if isLeft {
            HapticService.shared.playLeftHaptic()
            scoreBoard.triggerLeftTap()
        } else {
            HapticService.shared.playRightHaptic()
            scoreBoard.triggerRightTap()
        }

    }

    private func handleActionTypeSelected(_ pointType: PointType) {
        scoreBoard.confirmScoreAdjustment(pointType: pointType)
    }

    private func handleActionTypeCancelled() {
        scoreBoard.cancelScoreAdjustment()
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
                    onScoreAdjust: handleScoreAdjust
                )
                .focused($initialFocus)
                .background(
                    VStack(spacing: 2) {
                        ForEach(0..<7, id: \.self) { index in
                            if let player = scoreBoard.leftTeamPlayers[index] {
                                HStack {
                                    Circle()
                                        .fill(Color.blue.opacity(0.3))
                                        .frame(width: 4, height: 4)
                                    Text(player.displayName)
                                        .font(.system(size: 8, weight: .light))
                                        .foregroundColor(.white.opacity(0.2))
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.leading, 4)
                            }
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                )

                TapZoneView(
                    color: .red,
                    label: "RIGHT",
                    isLeft: false,
                    score: $scoreBoard.rightScore,
                    tapped: $scoreBoard.rightTapped,
                    suppress: $scoreBoard.suppressRightTap,
                    isLoading: scoreBoard.isLoading,
                    onScoreAdjust: handleScoreAdjust
                )
                .background(
                    VStack(spacing: 2) {
                        ForEach(0..<7, id: \.self) { index in
                            if let player = scoreBoard.rightTeamPlayers[index] {
                                HStack {
                                    Spacer()
                                    Text(player.displayName)
                                        .font(.system(size: 8, weight: .light))
                                        .foregroundColor(.white.opacity(0.2))
                                        .lineLimit(1)
                                    Circle()
                                        .fill(Color.red.opacity(0.3))
                                        .frame(width: 4, height: 4)
                                }
                                .padding(.trailing, 4)
                            }
                        }
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                )
            }
            .onAppear {
                initialFocus = true
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        showingMenu = true
                    } label: {
                        Text("⚙️")
                            .font(.title3)
                    }
                    .buttonStyle(.borderless)
                    .focusable(false)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.1), in: Circle())
                    Spacer()
                }
                .padding(.top, 4)
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
                    // HStack(spacing: 4) {
                    //     Circle()
                    //         .fill(watchConnectivity.isConnected ? .green : .red)
                    //         .frame(width: 4, height: 4)
                    //     Text(watchConnectivity.connectionStatus)
                    //         .font(.system(size: 7))
                    // }
                    // if watchConnectivity.audioLevel > 0 {
                    //     HStack(spacing: 2) {
                    //         Text("🎤")
                    //             .font(.system(size: 6))
                    //         Text(String(format: "%.2f", watchConnectivity.audioLevel))
                    //             .font(.system(size: 6))
                    //     }
                    // }
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
        .overlay(
            Group {
                if scoreBoard.showingActionTypeSelection {
                    ActionTypeSelectionView(
                        isLeft: scoreBoard.pendingScoreAdjustment?.isLeft ?? true,
                        onActionSelected: handleActionTypeSelected,
                        onCancel: handleActionTypeCancelled
                    )
                    .zIndex(1000)
                } else if scoreBoard.showingPlayerSelection {
                    PlayerSelectionView(
                        availableUsers: PlayerService.shared.getPlayersForPointAttribution(
                            isLeft: scoreBoard.pendingScoreAdjustment?.isLeft == true,
                            teamPlayers: scoreBoard.pendingScoreAdjustment?.isLeft == true ? scoreBoard.leftTeamPlayers : scoreBoard.rightTeamPlayers
                        ),
                        mode: .pointAttribution(team: scoreBoard.pendingScoreAdjustment?.isLeft == true ? .left : .right),
                        onPlayerSelected: { selectedUser in
                            scoreBoard.confirmScoreAdjustmentWithPlayer(selectedUser)
                        },
                        leftTeamPlayers: scoreBoard.leftTeamPlayers,
                        rightTeamPlayers: scoreBoard.rightTeamPlayers,
                        pointsHistory: scoreBoard.localPointsHistory
                    )
                    .zIndex(1000)
                } else if showingMenu {
                    MenuView(
                        points: scoreBoard.localPointsHistory,
                        onReset: {
                            scoreBoard.resetAll()
                        },
                        onShowHistory: {
                            showingHistory = true
                        },
                        onShowTeamSetup: {
                            showingTeamSelection = true
                        },
                        onCancel: {
                            showingMenu = false
                        },
                        resetDisabled: resetDisabled
                    )
                    .zIndex(1000)
                }
            }
        )
        .onAppear {
            initializeApp()
            setupSpeechRecognition()
        }
        .sheet(isPresented: $showingHistory) {
            PointsHistoryView(
                points: scoreBoard.localPointsHistory,
                onClose: {
                    showingHistory = false
                },
                onDeletePoint: { point in
                    scoreBoard.deleteSpecificPoint(point)
                }
            )
        }
        .fullScreenCover(isPresented: $showingTeamSelection) {
            TeamSelectionView(
                leftTeamPlayers: $scoreBoard.leftTeamPlayers,
                rightTeamPlayers: $scoreBoard.rightTeamPlayers,
                onBack: {
                    showingTeamSelection = false
                },
                onPlayerUpdated: { user, position, isLeft in
                    scoreBoard.updateTeamPlayer(user: user, position: position, isLeft: isLeft)
                }
            )
        }
        // .onReceive(NotificationCenter.default.publisher(for: .speechCommandReceived)) { notification in
        //     print("ContentView: 📢 Received speech command notification: \(notification)")
        //     if let command = notification.object as? String {
        //         print("ContentView: 🎯 Processing command: '\(command)'")
        //         scoreBoard.handleSpeechCommand(command)
        //         print("ContentView: ✅ Command processed and score synced")
        //     } else {
        //         print("ContentView: ❌ No command found in notification object")
        //     }
        // }
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
    
    private func setupSpeechRecognition() {
        //watchConnectivity.startListening()
    }
    
}

#Preview { ContentView() }
