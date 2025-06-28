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
    
    private let workoutKeepAlive = WorkoutKeepAlive()
    
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
        }
    }
    
    func resetAll() {
        leftWins = 0
        rightWins = 0
        leftScore = 0
        rightScore = 0
    }
    
    func adjustScore(isLeft: Bool, delta: Int) {
        if isLeft {
            leftScore = max(0, leftScore + delta)
        } else {
            rightScore = max(0, rightScore + delta)
        }
    }
    
    func createSetScore() -> SetScore {
        SetScore(day: today, left_score: leftScore, right_score: rightScore)
    }
    
    func createGlobalScore() -> GlobalScore {
        GlobalScore(day: today, left_wins: leftWins, right_wins: rightWins)
    }
    
    func updateConnectionStatus(_ status: String, color: Color) {
        connectionStatus = status
        connectionColor = color
    }
    
    func loadInitialState() async -> Bool {
        do {
            // Start workout keep alive to prevent app from sleeping
            workoutKeepAlive.start()
            
            // Run both SQL requests in parallel
            async let setScoreTask = SupabaseService.shared.fetchTodaysSetScore()
            async let globalScoreTask = SupabaseService.shared.fetchTodaysGlobalScore()
            
            let (setScore, globalScore) = try await (setScoreTask, globalScoreTask)
            
            // Update set scores if available
            if let setScore = setScore {
                leftScore = setScore.left_score
                rightScore = setScore.right_score
            }
            
            // Update global wins if available
            if let globalScore = globalScore {
                leftWins = globalScore.left_wins
                rightWins = globalScore.right_wins
            }
            
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
    
    deinit {
        workoutKeepAlive.stop()
    }
}