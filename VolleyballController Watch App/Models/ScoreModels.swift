import Foundation

struct SetScore: Encodable {
    let day: String
    let left_score: Int
    let right_score: Int
}

struct GlobalScore: Encodable {
    let day: String
    let left_wins: Int
    let right_wins: Int
}