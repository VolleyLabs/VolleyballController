import Foundation

protocol ScoreBoardActionDelegate: AnyObject {
    func addToLocalHistory(_ point: Point)
    func removeFromLocalHistory(at index: Int)
    func recalculateScoresFromPoints()
    func updateScores(leftScore: Int, rightScore: Int)
    func setLastAction(_ action: (isLeft: Bool, wasIncrement: Bool)?)
}

class ScoreBoardActionService {
    weak var delegate: ScoreBoardActionDelegate?
    private let dataService = ScoreBoardDataService.shared

    init(delegate: ScoreBoardActionDelegate? = nil) {
        self.delegate = delegate
    }

    func adjustScore(
        isLeft: Bool,
        delta: Int,
        pointType: PointType? = nil,
        playerId: Int? = nil,
        currentLeftScore: Int,
        currentRightScore: Int
    ) -> (newLeftScore: Int, newRightScore: Int) {
        delegate?.setLastAction((isLeft: isLeft, wasIncrement: delta > 0))

        let newLeftScore = isLeft ? max(0, currentLeftScore + delta) : currentLeftScore
        let newRightScore = isLeft ? currentRightScore : max(0, currentRightScore + delta)

        if delta > 0 {
            trackPoint(
                winner: isLeft ? .left : .right,
                pointType: pointType,
                playerId: playerId
            )
        }

        return (newLeftScore, newRightScore)
    }

    private func trackPoint(
        winner: PointWinner,
        pointType: PointType? = nil,
        playerId: Int? = nil
    ) {
        let point = Point(
            id: nil,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            winner: winner,
            type: pointType,
            playerId: playerId
        )

        delegate?.addToLocalHistory(point)
        delegate?.recalculateScoresFromPoints()

        Task {
            do {
                _ = try await dataService.trackPoint(winner: winner, pointType: pointType, playerId: playerId)
            } catch {
                print("❌ Failed to track point: \(error)")
                await MainActor.run {
                    // Find and remove the failed point from local history
                    // This is a simplified approach - in practice you'd want more specific matching
                    if let index = self.findPointIndex(for: point) {
                        self.delegate?.removeFromLocalHistory(at: index)
                        self.delegate?.recalculateScoresFromPoints()
                    }
                }
            }
        }
    }

    func deleteLastPointAndUpdateScore(
        localPointsHistory: [Point]
    ) {
        guard let lastPoint = localPointsHistory.last else {
            print("⚠️ No points in local history to delete")
            return
        }

        // Remove last point and recalculate
        delegate?.removeFromLocalHistory(at: localPointsHistory.count - 1)
        delegate?.recalculateScoresFromPoints()

        Task {
            do {
                let deletedPoint = try await dataService.deleteLastPoint()
                if deletedPoint == nil {
                    await MainActor.run {
                        self.delegate?.addToLocalHistory(lastPoint)
                        self.delegate?.recalculateScoresFromPoints()
                    }
                }
            } catch {
                print("❌ Failed to delete last point: \(error)")
                await MainActor.run {
                    self.delegate?.addToLocalHistory(lastPoint)
                    self.delegate?.recalculateScoresFromPoints()
                }
            }
        }
    }

    private func findPointIndex(for point: Point) -> Int? {
        // This is a simplified implementation
        // In practice, you'd want more sophisticated matching
        return nil
    }
}
