import Foundation

enum PointType: String, Codable, CaseIterable {
    case ace = "ace"
    case attack = "attack"
    case block = "block"
    case error = "error"
    case other = "unspecified"

    var emoji: String {
        switch self {
        case .ace: return "🎯"
        case .attack: return "🏐"
        case .block: return "🛡️"
        case .error: return "❌"
        case .other: return "∅"
        }
    }

    var displayName: String {
        switch self {
        case .ace: return "Ace"
        case .attack: return "Attack"
        case .block: return "Block"
        case .error: return "Error"
        case .other: return "Other"
        }
    }
}
