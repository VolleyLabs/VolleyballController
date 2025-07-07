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
            // For point attribution, show only the relevant team's players first
            let teamPlayers = team == .left ? leftTeamPlayers : rightTeamPlayers
            let teamPlayerUsers = teamPlayers.compactMap { $0 }
            let teamPlayerIds = Set(teamPlayerUsers.compactMap { $0.id })
            
            let currentTeamUsers = availableUsers.filter { user in
                teamPlayerIds.contains(user.id ?? -1)
            }
            let otherUsers = availableUsers.filter { user in
                !teamPlayerIds.contains(user.id ?? -1)
            }
            
            return currentTeamUsers + otherUsers
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                
                ForEach(sortedUsers, id: \.id) { user in
                    let isSelected = (leftTeamPlayers + rightTeamPlayers).compactMap { $0 }.contains { $0.id == user.id }
                    let isCurrentTeamPlayer = relevantTeamPlayers.compactMap { $0 }.contains { $0.id == user.id }
                    
                    Button(action: {
                        onPlayerSelected(user)
                    }) {
                        HStack {
                            Text(user.displayName)
                                .font(.callout)
                                .fontWeight(.medium)
                                .foregroundColor(getTextColor(isSelected: isSelected, isCurrentTeam: isCurrentTeamPlayer))
                                .lineLimit(1)
                                .truncationMode(.tail)
                            
                            Spacer()
                            
                            if case .pointAttribution = mode, isCurrentTeamPlayer {
                                Text("⭐")
                                    .font(.caption2)
                                    .foregroundColor(mode.titleColor)
                            } else if isSelected {
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
                                .fill(getBackgroundColor(isSelected: isSelected, isCurrentTeam: isCurrentTeamPlayer))
                                .stroke(getStrokeColor(isSelected: isSelected, isCurrentTeam: isCurrentTeamPlayer), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
                
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