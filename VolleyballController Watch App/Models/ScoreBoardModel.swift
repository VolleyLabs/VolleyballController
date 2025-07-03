import SwiftUI
import Foundation

@Observable
class ScoreBoardModel {
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
    
    private let workoutKeepAlive = WorkoutKeepAlive()
    private var lastAction: (isLeft: Bool, wasIncrement: Bool)?
    private var currentSetNumber = 1
    var pendingScoreAdjustment: (isLeft: Bool, delta: Int, player: String?)?
    var localPointsHistory: [Point] = []
    
    private var today: String {
        ISO8601DateFormatter().string(from: Date()).prefix(10).description
    }
    
    var winner: String {
        leftScore == rightScore ? "Tie" : (leftScore > rightScore ? "Left" : "Right")
    }
    
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
                // Delete all today's points from database
                try await SupabaseService.shared.deleteAllTodaysPoints()
                
                // Clear local cache and reset all scores
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
                // Even if database deletion fails, reset local state
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
                // Remove from local history immediately (optimistic update)
                await MainActor.run {
                    if let index = localPointsHistory.firstIndex(where: { $0.id == point.id }) {
                        localPointsHistory.remove(at: index)
                        recalculateScoresFromPoints()
                        print("✅ Point removed from local history and scores recalculated")
                    }
                }
                
                // Delete from database
                try await SupabaseService.shared.deleteSpecificPoint(point)
                print("✅ Point deleted from database successfully")
                
            } catch {
                print("❌ Failed to delete specific point: \(error)")
                // Restore point to local history if database deletion failed
                await MainActor.run {
                    // Find correct position to re-insert based on created_at
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
    
    func requestScoreAdjustment(isLeft: Bool, delta: Int, player: String? = nil) {
        // For score decreases, delete last point and adjust score accordingly
        if delta <= 0 {
            deleteLastPointAndUpdateScore()
            return
        }
        
        // For score increases, show action type selection
        pendingScoreAdjustment = (isLeft: isLeft, delta: delta, player: player)
        showingActionTypeSelection = true
    }
    
    func confirmScoreAdjustment(pointType: PointType) {
        guard let pending = pendingScoreAdjustment else { return }
        
        adjustScore(
            isLeft: pending.isLeft,
            delta: pending.delta,
            pointType: pointType,
            player: pending.player
        )
        
        // Play haptic feedback for confirmation
        if pending.isLeft {
            HapticService.shared.playLeftHaptic()
        } else {
            HapticService.shared.playRightHaptic()
        }
        
        // Clear pending state
        pendingScoreAdjustment = nil
        showingActionTypeSelection = false
    }
    
    func cancelScoreAdjustment() {
        HapticService.shared.playCancelHaptic()
        pendingScoreAdjustment = nil
        showingActionTypeSelection = false
    }
    
    private func adjustScore(isLeft: Bool, delta: Int, pointType: PointType? = nil, player: String? = nil) {
        let leftScoreBefore = leftScore
        let rightScoreBefore = rightScore
        
        lastAction = (isLeft: isLeft, wasIncrement: delta > 0)
        
        if isLeft {
            leftScore = max(0, leftScore + delta)
        } else {
            rightScore = max(0, rightScore + delta)
        }
        
        // Only track points when score increases
        if delta > 0 {
            trackPoint(
                winner: isLeft ? .left : .right,
                leftScoreBefore: leftScoreBefore,
                rightScoreBefore: rightScoreBefore,
                leftScoreAfter: leftScore,
                rightScoreAfter: rightScore,
                pointType: pointType,
                player: player
            )
        }
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
    
    func handleSpeechCommand(_ command: String) {
        print("ScoreBoardModel: 🎯 Handling speech command: '\(command)'")
        switch command {
        case "left":
            print("ScoreBoardModel: ⬅️ Processing LEFT command")
            requestScoreAdjustment(isLeft: true, delta: 1)
            HapticService.shared.playLeftHaptic()
            triggerLeftTap()
            print("ScoreBoardModel: ✅ LEFT score adjustment requested")
        case "right":
            print("ScoreBoardModel: ➡️ Processing RIGHT command")
            requestScoreAdjustment(isLeft: false, delta: 1)
            HapticService.shared.playRightHaptic()
            triggerRightTap()
            print("ScoreBoardModel: ✅ RIGHT score adjustment requested")
        case "cancel":
            print("ScoreBoardModel: ❌ Processing CANCEL command")
            undoLastAction()
            HapticService.shared.playCancelHaptic()
            print("ScoreBoardModel: ✅ CANCEL action completed")
        default:
            print("ScoreBoardModel: ❓ Unknown command: '\(command)'")
            break
        }
    }
    
    func undoLastAction() {
        guard let lastAction = lastAction else { return }
        
        if lastAction.wasIncrement {
            // If last action was an increment, we need to delete from DB and adjust score accordingly
            deleteLastPointAndUpdateScore()
        } else {
            // If last action was a decrement, we need to increment (no DB operation needed)
            let undoDelta = 1
            adjustScore(isLeft: lastAction.isLeft, delta: undoDelta)
        }
        
        HapticService.shared.playCancelHaptic()
        self.lastAction = nil
    }
    
    
    func updateConnectionStatus(_ status: String, color: Color) {
        connectionStatus = status
        connectionColor = color
    }
    
    func loadInitialState() async -> Bool {
        do {
            // Start workout keep alive to prevent app from sleeping
            workoutKeepAlive.start()
            
            // Load basic points from database
            let points = try await SupabaseService.shared.fetchTodaysPoints()
            
            // Store points in local history for optimistic updates
            localPointsHistory = points
            
            // Recalculate scores and sets from points
            recalculateScoresFromPoints()
            
            print("📊 Loaded \(points.count) points")
            print("📊 Current scores: \(leftScore)-\(rightScore) in set \(currentSetNumber)")
            print("📊 Set wins: Left \(leftWins) - Right \(rightWins)")
            
            isLoading = false
            return true
        } catch {
            print("Failed to load initial state: \(error)")
            isLoading = false
            return false
        }
    }
    
    func stopWorkout() {
        workoutKeepAlive.stop()
    }
    
    private func trackPoint(
        winner: PointWinner,
        leftScoreBefore: Int,
        rightScoreBefore: Int,
        leftScoreAfter: Int,
        rightScoreAfter: Int,
        pointType: PointType? = nil,
        player: String? = nil
    ) {
        let point = Point(
            id: nil,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            winner: winner,
            type: pointType,
            playerId: nil
        )
        
        // Add to local history immediately for optimistic updates
        localPointsHistory.append(point)
        
        // Recalculate scores from updated local history
        recalculateScoresFromPoints()
        
        Task {
            do {
                try await SupabaseService.shared.addPoint(point)
                print("✅ Point tracked successfully")
            } catch {
                print("❌ Failed to track point: \(error)")
                // On failure, remove from local history and recalculate
                await MainActor.run {
                    if let index = localPointsHistory.firstIndex(where: { $0.createdAt == point.createdAt && $0.winner == point.winner }) {
                        localPointsHistory.remove(at: index)
                        recalculateScoresFromPoints()
                    }
                }
            }
        }
    }
    
    private func deleteLastPointAndUpdateScore() {
        // Optimistic update: immediately update UI using local history
        guard let lastPoint = localPointsHistory.last else {
            print("⚠️ No points in local history to delete")
            return
        }
        
        // Remove from local history immediately
        localPointsHistory.removeLast()
        
        // Recalculate scores from updated local history
        recalculateScoresFromPoints()
        
        // Then sync with database in background
        Task {
            do {
                let deletedPoint = try await SupabaseService.shared.deleteLastPoint()
                if let point = deletedPoint {
                    print("✅ Last point deleted successfully: \(point.winner)")
                } else {
                    print("⚠️ No point found to delete in database")
                    // If database deletion failed, restore the point locally
                    await MainActor.run {
                        localPointsHistory.append(lastPoint)
                        recalculateScoresFromPoints()
                    }
                }
            } catch {
                print("❌ Failed to delete last point: \(error)")
                // If database deletion failed, restore the point locally
                await MainActor.run {
                    localPointsHistory.append(lastPoint)
                    recalculateScoresFromPoints()
                }
            }
        }
    }
    
    private func recalculateScoresFromPoints() {
        // Reset all scores
        leftScore = 0
        rightScore = 0
        leftWins = 0
        rightWins = 0
        currentSetNumber = 1
        
        // Calculate running scores and detect set boundaries
        for point in localPointsHistory {
            // Add point to current set
            if point.winner == .left {
                leftScore += 1
            } else {
                rightScore += 1
            }
            
            // Check if set is complete (25+ points with 2+ advantage)
            let isSetComplete = (leftScore >= 25 || rightScore >= 25) && abs(leftScore - rightScore) >= 2
            
            if isSetComplete {
                // Set completed, record winner and start new set
                if leftScore > rightScore {
                    leftWins += 1
                    print("📊 Set \(currentSetNumber) completed: Left won \(leftScore)-\(rightScore)")
                } else {
                    rightWins += 1
                    print("📊 Set \(currentSetNumber) completed: Right won \(leftScore)-\(rightScore)")
                }
                
                // Start new set
                currentSetNumber += 1
                leftScore = 0
                rightScore = 0
            }
        }
        
        print("📊 Current state: \(leftScore)-\(rightScore) in set \(currentSetNumber), wins: \(leftWins)-\(rightWins)")
    }
    
    deinit {
        workoutKeepAlive.stop()
    }
}