import Foundation

struct Point: Codable, Identifiable {
    let id: String?
    let createdAt: String?
    let winner: PointWinner
    let type: PointType?
    let playerId: Int?

    private enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case winner
        case type
        case playerId = "player_id"
    }
}
