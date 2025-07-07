import Foundation

class ScoreBoardDataService {
    static let shared = ScoreBoardDataService()

    private init() {}

    private var today: String {
        ISO8601DateFormatter().string(from: Date()).prefix(10).description
    }

    func loadInitialState() async throws -> [Point] {
        let points = try await SupabaseService.shared.fetchTodaysPoints()
        print("📊 Loaded \(points.count) points")
        return points
    }

    func trackPoint(
        winner: PointWinner,
        pointType: PointType? = nil,
        playerId: Int? = nil
    ) async throws -> Point {
        let point = Point(
            id: nil,
            createdAt: ISO8601DateFormatter().string(from: Date()),
            winner: winner,
            type: pointType,
            playerId: playerId
        )

        try await SupabaseService.shared.addPoint(point)
        print("✅ Point tracked successfully")
        return point
    }

    func deleteLastPoint() async throws -> Point? {
        let deletedPoint = try await SupabaseService.shared.deleteLastPoint()
        if let point = deletedPoint {
            print("✅ Last point deleted successfully: \(point.winner)")
        } else {
            print("⚠️ No point found to delete in database")
        }
        return deletedPoint
    }

    func deleteSpecificPoint(_ point: Point) async throws {
        try await SupabaseService.shared.deleteSpecificPoint(point)
        print("✅ Point deleted from database successfully")
    }

    func deleteAllTodaysPoints() async throws {
        try await SupabaseService.shared.deleteAllTodaysPoints()
        print("✅ Reset completed: All data cleared")
    }
}
