import SwiftUI
import Foundation

@Observable
class ScoreBoardModel {
    var leftScore = 0
    var rightScore = 0
    var leftWins = 0
    var rightWins = 0
    var crownLeft = 0.0
    var crownRight = 0.0
    var leftTapped = false
    var rightTapped = false
    var suppressLeftTap = false
    var suppressRightTap = false
    var connectionStatus: String = "Connecting..."
    var connectionColor: Color = .orange
    
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
}