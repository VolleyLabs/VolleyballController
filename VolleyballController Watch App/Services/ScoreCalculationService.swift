import Foundation

class ScoreCalculationService {
    static let shared = ScoreCalculationService()

    private init() {}

    struct ScoreResult {
        let leftScore: Int
        let rightScore: Int
        let leftWins: Int
        let rightWins: Int
        let currentSetNumber: Int
    }

    func recalculateScoresFromPoints(_ points: [Point]) -> ScoreResult {
        // Reset all scores
        var leftScore = 0
        var rightScore = 0
        var leftWins = 0
        var rightWins = 0
        var currentSetNumber = 1

        // Calculate running scores and detect set boundaries
        for point in points {
            // Add point to current set
            if point.winner == .left {
                leftScore += 1
            } else {
                rightScore += 1
            }

            // Check if set is complete (25+ points with 2+ advantage)
            let hasMinimumScore = leftScore >= 25 || rightScore >= 25
            let hasSufficientAdvantage = abs(leftScore - rightScore) >= 2
            let isSetComplete = hasMinimumScore && hasSufficientAdvantage

            if isSetComplete {
                // Set completed, record winner and start new set
                if leftScore > rightScore {
                    leftWins += 1
                    print("📊 Set \(currentSetNumber) completed: " +
                          "Left won \(leftScore)-\(rightScore)")
                } else {
                    rightWins += 1
                    print("📊 Set \(currentSetNumber) completed: " +
                          "Right won \(leftScore)-\(rightScore)")
                }

                // Start new set
                currentSetNumber += 1
                leftScore = 0
                rightScore = 0
            }
        }

        print("📊 Current state: \(leftScore)-\(rightScore) in set \(currentSetNumber), " +
              "wins: \(leftWins)-\(rightWins)")

        return ScoreResult(
            leftScore: leftScore,
            rightScore: rightScore,
            leftWins: leftWins,
            rightWins: rightWins,
            currentSetNumber: currentSetNumber
        )
    }

    func calculateWinner(leftScore: Int, rightScore: Int) -> String {
        leftScore == rightScore ? "Tie" : (leftScore > rightScore ? "Left" : "Right")
    }
}
