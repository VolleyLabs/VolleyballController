import Foundation

enum TeamSide: String, CaseIterable {
    case left = "left"
    case right = "right"
    
    var displayName: String {
        switch self {
        case .left: return "Blue Team"
        case .right: return "Red Team"
        }
    }
}