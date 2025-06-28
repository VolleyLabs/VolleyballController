import Foundation

struct SetScore: Codable {
    let day: String
    let left_score: Int
    let right_score: Int
}

struct GlobalScore: Codable {
    let day: String
    let left_wins: Int
    let right_wins: Int
}