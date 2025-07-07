import Foundation

struct User: Codable, Identifiable {
    let id: Int?
    let createdAt: String?
    let firstName: String
    let lastName: String?
    let username: String?
    let photoUrl: String?
    let admin: Bool?
    let chatId: String?
    let pickupHeight: Int?
    
    var displayName: String {
        if let username = username, !username.isEmpty {
            return "@\(username)"
        } else if let lastName = lastName, !lastName.isEmpty {
            return "\(firstName) \(lastName)"
        } else {
            return firstName
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case firstName = "first_name"
        case lastName = "last_name"
        case username
        case photoUrl = "photo_url"
        case admin
        case chatId = "chat_id"
        case pickupHeight = "pickup_height"
    }
}