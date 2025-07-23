import SwiftUI

enum PlayerSelectionMode {
    case teamSetup(position: Int, team: TeamSide)
    case pointAttribution(team: TeamSide)
    
    var titleText: String {
        switch self {
        case .teamSetup(let position, _):
            return "Position \(position)"
        case .pointAttribution(_):
            return "Player"
        }
    }
    
    var titleColor: Color {
        switch self {
        case .teamSetup(_, let team), .pointAttribution(let team):
            return team == .left ? .cyan : .orange
        }
    }
}

struct PlayerSelectionView: View {
    let availableUsers: [User]
    let mode: PlayerSelectionMode
    let onPlayerSelected: (User?) -> Void
    let leftTeamPlayers: [User?]
    let rightTeamPlayers: [User?]
    let pointsHistory: [Point]
    
    @Environment(\.dismiss) private var dismiss
    
    private var relevantTeamPlayers: [User?] {
        switch mode {
        case .teamSetup(_, let team), .pointAttribution(let team):
            return team == .left ? leftTeamPlayers : rightTeamPlayers
        }
    }
    
    private var sortedUsers: [User] {
        switch mode {
        case .teamSetup:
            // For team setup, show all users first, then selected ones at the end
            let allSelectedUsers = (leftTeamPlayers + rightTeamPlayers).compactMap { $0 }
            let selectedUserIds = Set(allSelectedUsers.compactMap { $0.id })
            
            let unselectedUsers = availableUsers.filter { user in
                !selectedUserIds.contains(user.id ?? -1)
            }
            let selectedUsers = availableUsers.filter { user in
                selectedUserIds.contains(user.id ?? -1)
            }
            
            return unselectedUsers + selectedUsers
            
        case .pointAttribution(let team):
            // For point attribution, use the new sorting method that prioritizes by points
            return PlayerService.shared.getPlayersSortedByPoints(
                isLeft: team == .left,
                teamPlayers: team == .left ? leftTeamPlayers : rightTeamPlayers,
                pointsHistory: pointsHistory
            )
        }
    }
    
    private var playerPointCounts: [Int64: Int] {
        var counts: [Int64: Int] = [:]
        for point in pointsHistory {
            if let playerId = point.playerId {
                counts[playerId, default: 0] += 1
            }
        }
        return counts
    }
    
    private func sortPlayersByPoints(_ players: [User]) -> [User] {
        return players.sorted { user1, user2 in
            let points1 = playerPointCounts[user1.id ?? -1] ?? 0
            let points2 = playerPointCounts[user2.id ?? -1] ?? 0
            
            if points1 != points2 {
                return points1 > points2  // Higher points first
            }
            return user1.displayName.localizedCaseInsensitiveCompare(user2.displayName) == .orderedAscending  // Then alphabetically
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                
                // Show players with skip button positioned after team players for point attribution
                if case .pointAttribution = mode {
                    let teamPlayers = sortPlayersByPoints(sortedUsers.filter { user in
                        relevantTeamPlayers.compactMap { $0 }.contains { $0.id == user.id }
                    })
                    
                    // Get opposite team players and sort them by points
                    let oppositeTeamPlayers = sortPlayersByPoints(sortedUsers.filter { user in
                        let oppositeTeamPlayers = mode.titleColor == .cyan ? rightTeamPlayers : leftTeamPlayers
                        return oppositeTeamPlayers.compactMap { $0 }.contains { $0.id == user.id }
                    })
                    
                    // Get truly other players (not on either team)
                    let allTeamPlayerIds = Set((leftTeamPlayers + rightTeamPlayers).compactMap { $0?.id })
                    let otherPlayers = sortedUsers.filter { user in
                        !allTeamPlayerIds.contains(user.id ?? -1)
                    }.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
                    
                    // Team players first
                    ForEach(teamPlayers, id: \.id) { user in
                        PlayerRowView(
                            user: user,
                            mode: mode,
                            relevantTeamPlayers: relevantTeamPlayers,
                            leftTeamPlayers: leftTeamPlayers,
                            rightTeamPlayers: rightTeamPlayers,
                            playerPointCounts: playerPointCounts,
                            onPlayerSelected: onPlayerSelected
                        )
                    }
                    
                    // Skip button after team players
                    SkipButtonView(onPlayerSelected: onPlayerSelected)
                    
                    // Opposite team players next
                    ForEach(oppositeTeamPlayers, id: \.id) { user in
                        PlayerRowView(
                            user: user,
                            mode: mode,
                            relevantTeamPlayers: relevantTeamPlayers,
                            leftTeamPlayers: leftTeamPlayers,
                            rightTeamPlayers: rightTeamPlayers,
                            playerPointCounts: playerPointCounts,
                            onPlayerSelected: onPlayerSelected
                        )
                    }
                    
                    // Other players last
                    ForEach(otherPlayers, id: \.id) { user in
                        PlayerRowView(
                            user: user,
                            mode: mode,
                            relevantTeamPlayers: relevantTeamPlayers,
                            leftTeamPlayers: leftTeamPlayers,
                            rightTeamPlayers: rightTeamPlayers,
                            playerPointCounts: playerPointCounts,
                            onPlayerSelected: onPlayerSelected
                        )
                    }
                } else {
                    // For team setup mode, keep original behavior
                    ForEach(sortedUsers, id: \.id) { user in
                        PlayerRowView(
                            user: user,
                            mode: mode,
                            relevantTeamPlayers: relevantTeamPlayers,
                            leftTeamPlayers: leftTeamPlayers,
                            rightTeamPlayers: rightTeamPlayers,
                            playerPointCounts: playerPointCounts,
                            onPlayerSelected: onPlayerSelected
                        )
                    }
                    
                    // Skip button at the end for team setup
                    SkipButtonView(onPlayerSelected: onPlayerSelected)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }
    
    private func getTextColor(isSelected: Bool, isCurrentTeam: Bool) -> Color {
        if case .pointAttribution = mode, isCurrentTeam {
            return .white
        } else if isSelected {
            return .gray
        } else {
            return .white
        }
    }
    
    private func getBackgroundColor(isSelected: Bool, isCurrentTeam: Bool) -> Color {
        if case .pointAttribution = mode, isCurrentTeam {
            return mode.titleColor.opacity(0.3)
        } else if isSelected {
            return Color.gray.opacity(0.1)
        } else {
            return mode.titleColor.opacity(0.2)
        }
    }
    
    private func getStrokeColor(isSelected: Bool, isCurrentTeam: Bool) -> Color {
        if case .pointAttribution = mode, isCurrentTeam {
            return mode.titleColor.opacity(0.8)
        } else if isSelected {
            return Color.gray.opacity(0.3)
        } else {
            return mode.titleColor.opacity(0.6)
        }
    }
}

struct PlayerRowView: View {
    let user: User
    let mode: PlayerSelectionMode
    let relevantTeamPlayers: [User?]
    let leftTeamPlayers: [User?]
    let rightTeamPlayers: [User?]
    let playerPointCounts: [Int64: Int]
    let onPlayerSelected: (User?) -> Void
    
    private var isSelected: Bool {
        (leftTeamPlayers + rightTeamPlayers).compactMap { $0 }.contains { $0.id == user.id }
    }
    
    private var isCurrentTeamPlayer: Bool {
        relevantTeamPlayers.compactMap { $0 }.contains { $0.id == user.id }
    }
    
    private var isOppositeTeamPlayer: Bool {
        guard case .pointAttribution(let team) = mode else { return false }
        let oppositeTeamPlayers = team == .left ? rightTeamPlayers : leftTeamPlayers
        return oppositeTeamPlayers.compactMap { $0 }.contains { $0.id == user.id }
    }
    
    var body: some View {
        Button(action: {
            onPlayerSelected(user)
        }) {
            HStack {
                Text(user.displayName)
                    .font(.callout)
                    .fontWeight(.medium)
                    .foregroundColor(getTextColor(isSelected: isSelected, isCurrentTeam: isCurrentTeamPlayer, isOppositeTeam: isOppositeTeamPlayer))
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
                
                if case .pointAttribution = mode, isCurrentTeamPlayer {
                    let pointCount = playerPointCounts[user.id ?? -1] ?? 0
                    if pointCount > 0 {
                        Text("\(pointCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(mode.titleColor)
                    }
                } else if case .pointAttribution = mode, isOppositeTeamPlayer {
                    let pointCount = playerPointCounts[user.id ?? -1] ?? 0
                    if pointCount > 0 {
                        let oppositeColor: Color = mode.titleColor == .cyan ? .orange : .cyan
                        Text("\(pointCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(oppositeColor)
                    }
                } else if case .teamSetup = mode, isSelected {
                    Text("✓")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(getBackgroundColor(isSelected: isSelected, isCurrentTeam: isCurrentTeamPlayer, isOppositeTeam: isOppositeTeamPlayer))
                    .stroke(getStrokeColor(isSelected: isSelected, isCurrentTeam: isCurrentTeamPlayer, isOppositeTeam: isOppositeTeamPlayer), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func getTextColor(isSelected: Bool, isCurrentTeam: Bool, isOppositeTeam: Bool = false) -> Color {
        if case .pointAttribution = mode, isCurrentTeam {
            return .white
        } else if case .pointAttribution = mode, isOppositeTeam {
            return .white
        } else if isSelected {
            return .gray
        } else {
            return .white
        }
    }
    
    private func getBackgroundColor(isSelected: Bool, isCurrentTeam: Bool, isOppositeTeam: Bool = false) -> Color {
        if case .pointAttribution = mode, isCurrentTeam {
            return mode.titleColor.opacity(0.3)
        } else if case .pointAttribution = mode, isOppositeTeam {
            let oppositeColor: Color = mode.titleColor == .cyan ? .orange : .cyan
            return oppositeColor.opacity(0.2)
        } else if isSelected {
            return Color.gray.opacity(0.1)
        } else {
            // Make other players neutral colored
            return Color.gray.opacity(0.1)
        }
    }
    
    private func getStrokeColor(isSelected: Bool, isCurrentTeam: Bool, isOppositeTeam: Bool = false) -> Color {
        if case .pointAttribution = mode, isCurrentTeam {
            return mode.titleColor.opacity(0.8)
        } else if case .pointAttribution = mode, isOppositeTeam {
            let oppositeColor: Color = mode.titleColor == .cyan ? .orange : .cyan
            return oppositeColor.opacity(0.5)
        } else if isSelected {
            return Color.gray.opacity(0.3)
        } else {
            // Make other players neutral colored
            return Color.gray.opacity(0.3)
        }
    }
}

struct SkipButtonView: View {
    let onPlayerSelected: (User?) -> Void
    
    var body: some View {
        Button(action: {
            onPlayerSelected(nil)
        }) {
            Text("—")
                .font(.title3)
                .fontWeight(.light)
                .foregroundColor(.gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.1))
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}