import SwiftUI
import Foundation

struct PendingScoreAdjustment {
    let isLeft: Bool
    let delta: Int
    let playerId: Int?
}

@Observable
class ScoreBoardModel: SpeechCommandHandlerDelegate, ScoreBoardActionDelegate {
    var leftScore = 0
    var rightScore = 0
    var leftWins = 0
    var rightWins = 0
    var leftTapped = false
    var rightTapped = false
    var suppressLeftTap = false
    var suppressRightTap = false
    var connectionStatus: String = "Connecting..."
    var connectionColor: Color = .orange
    var isLoading: Bool = true
    var showingActionTypeSelection: Bool = false
    var showingPlayerSelection: Bool = false
    var selectedPointType: PointType?

    private let workoutKeepAlive = WorkoutKeepAlive()
    private let speechCommandHandler: SpeechCommandHandler
    private let dataService = ScoreBoardDataService.shared
    private let calculationService = ScoreCalculationService.shared
    private let actionService: ScoreBoardActionService
    private var lastAction: (isLeft: Bool, wasIncrement: Bool)?
    private var currentSetNumber = 1
    var pendingScoreAdjustment: PendingScoreAdjustment?
    var localPointsHistory: [Point] = []
    var leftTeamPlayers: [User?] = Array(repeating: nil, count: 7)
    var rightTeamPlayers: [User?] = Array(repeating: nil, count: 7)

    init() {
        speechCommandHandler = SpeechCommandHandler()
        actionService = ScoreBoardActionService()
        speechCommandHandler.delegate = self
        actionService.delegate = self
    }

    var winner: String {
        calculationService.calculateWinner(leftScore: leftScore, rightScore: rightScore)
    }

    // MARK: - ScoreBoardActionDelegate
    func addToLocalHistory(_ point: Point) {
        localPointsHistory.append(point)
    }

    func removeFromLocalHistory(at index: Int) {
        localPointsHistory.remove(at: index)
    }

    func updateScores(leftScore: Int, rightScore: Int) {
        self.leftScore = leftScore
        self.rightScore = rightScore
    }

    func setLastAction(_ action: (isLeft: Bool, wasIncrement: Bool)?) {
        lastAction = action
    }

    func recalculateScoresFromPoints() {
        let result = calculationService.recalculateScoresFromPoints(localPointsHistory)
        leftScore = result.leftScore
        rightScore = result.rightScore
        leftWins = result.leftWins
        rightWins = result.rightWins
        currentSetNumber = result.currentSetNumber
    }

    // MARK: - Public Methods
    func finishSet() {
        if leftScore != rightScore {
            if leftScore > rightScore {
                leftWins += 1
            } else {
                rightWins += 1
            }
            leftScore = 0
            rightScore = 0
            currentSetNumber += 1
        }
    }

    func resetAll() {
        Task {
            do {
                try await dataService.deleteAllTodaysPoints()
                await MainActor.run {
                    localPointsHistory.removeAll()
                    leftWins = 0
                    rightWins = 0
                    leftScore = 0
                    rightScore = 0
                    currentSetNumber = 1
                    lastAction = nil
                    print("✅ Reset completed: All data cleared")
                }
            } catch {
                print("❌ Failed to reset all data: \(error)")
                await MainActor.run {
                    localPointsHistory.removeAll()
                    leftWins = 0
                    rightWins = 0
                    leftScore = 0
                    rightScore = 0
                    currentSetNumber = 1
                    lastAction = nil
                    print("⚠️ Local reset completed, but database deletion failed")
                }
            }
        }
    }

    func deleteSpecificPoint(_ point: Point) {
        Task {
            do {
                await MainActor.run {
                    if let index = localPointsHistory.firstIndex(where: { $0.id == point.id }) {
                        localPointsHistory.remove(at: index)
                        recalculateScoresFromPoints()
                        print("✅ Point removed from local history and scores recalculated")
                    }
                }

                try await dataService.deleteSpecificPoint(point)
            } catch {
                print("❌ Failed to delete specific point: \(error)")
                await MainActor.run {
                    if let createdAt = point.createdAt {
                        let insertIndex = localPointsHistory.firstIndex { existingPoint in
                            guard let existingCreatedAt = existingPoint.createdAt else { return false }
                            return existingCreatedAt > createdAt
                        } ?? localPointsHistory.count

                        localPointsHistory.insert(point, at: insertIndex)
                        recalculateScoresFromPoints()
                        print("⚠️ Point restored to local history due to database deletion failure")
                    }
                }
            }
        }
    }

    func requestScoreAdjustment(isLeft: Bool, delta: Int, playerId: Int? = nil) {
        if delta <= 0 {
            actionService.deleteLastPointAndUpdateScore(localPointsHistory: localPointsHistory)
            return
        }

        pendingScoreAdjustment = PendingScoreAdjustment(isLeft: isLeft, delta: delta, playerId: playerId)
        showingActionTypeSelection = true
    }

    func confirmScoreAdjustment(pointType: PointType) {
        guard let pending = pendingScoreAdjustment else { return }

        // For Ace, Attack, and Block point types, show player selection
        if pointType == .ace || pointType == .attack || pointType == .block {
            selectedPointType = pointType
            showingActionTypeSelection = false
            showingPlayerSelection = true
            return
        }

        // For Error and other point types, proceed as normal
        let result = actionService.adjustScore(
            isLeft: pending.isLeft,
            delta: pending.delta,
            pointType: pointType,
            playerId: pending.playerId,
            currentLeftScore: leftScore,
            currentRightScore: rightScore
        )

        leftScore = result.newLeftScore
        rightScore = result.newRightScore

        if pending.isLeft {
            HapticService.shared.playLeftHaptic()
        } else {
            HapticService.shared.playRightHaptic()
        }

        pendingScoreAdjustment = nil
        showingActionTypeSelection = false
    }

    func confirmScoreAdjustmentWithPlayer(_ selectedUser: User?) {
        guard let pending = pendingScoreAdjustment,
              let pointType = selectedPointType else { return }

        let result = actionService.adjustScore(
            isLeft: pending.isLeft,
            delta: pending.delta,
            pointType: pointType,
            playerId: selectedUser?.id,
            currentLeftScore: leftScore,
            currentRightScore: rightScore
        )

        leftScore = result.newLeftScore
        rightScore = result.newRightScore

        if pending.isLeft {
            HapticService.shared.playLeftHaptic()
        } else {
            HapticService.shared.playRightHaptic()
        }

        pendingScoreAdjustment = nil
        showingPlayerSelection = false
        selectedPointType = nil
    }
    
    func cancelPlayerSelection() {
        showingPlayerSelection = false
        selectedPointType = nil
        // Return to action type selection
        showingActionTypeSelection = true
    }

    func cancelScoreAdjustment() {
        HapticService.shared.playCancelHaptic()
        pendingScoreAdjustment = nil
        showingActionTypeSelection = false
        showingPlayerSelection = false
        selectedPointType = nil
    }

    func triggerLeftTap() {
        leftTapped = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.leftTapped = false
        }
    }

    func triggerRightTap() {
        rightTapped = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.rightTapped = false
        }
    }

    func updateConnectionStatus(_ status: String, color: Color) {
        connectionStatus = status
        connectionColor = color
    }

    func handleSpeechCommand(_ command: String) {
        speechCommandHandler.handleSpeechCommand(command)
    }

    func undoLastAction() {
        guard let lastAction = lastAction else { return }

        if lastAction.wasIncrement {
            actionService.deleteLastPointAndUpdateScore(localPointsHistory: localPointsHistory)
        } else {
            let result = actionService.adjustScore(
                isLeft: lastAction.isLeft,
                delta: 1,
                currentLeftScore: leftScore,
                currentRightScore: rightScore
            )
            leftScore = result.newLeftScore
            rightScore = result.newRightScore
        }

        HapticService.shared.playCancelHaptic()
        self.lastAction = nil
    }

    func stopWorkout() {
        workoutKeepAlive.stop()
    }

    func loadInitialState() async -> Bool {
        do {
            workoutKeepAlive.start()
            
            // Load points and players in parallel
            async let pointsTask = dataService.loadInitialState()
            async let playersTask = PlayerService.shared.loadPlayersAsync()
            
            // Wait for points to complete (critical path)
            let points = try await pointsTask
            localPointsHistory = points
            recalculateScoresFromPoints()
            
            // Wait for players to complete (non-blocking)
            await playersTask
            
            print("📊 Current scores: \(leftScore)-\(rightScore) in set \(currentSetNumber)")
            print("📊 Set wins: Left \(leftWins) - Right \(rightWins)")
            print("👥 Players loaded: \(PlayerService.shared.players.count)")
            isLoading = false
            return true
        } catch {
            print("Failed to load initial state: \(error)")
            isLoading = false
            return false
        }
    }
    
    func updateTeamPlayer(user: User?, position: Int, isLeft: Bool) {
        let index = position - 1 // Convert to 0-based index
        if isLeft {
            leftTeamPlayers[index] = user
        } else {
            rightTeamPlayers[index] = user
        }
    }

    deinit {
        workoutKeepAlive.stop()
    }
}
