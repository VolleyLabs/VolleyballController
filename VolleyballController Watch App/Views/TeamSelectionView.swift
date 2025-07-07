import SwiftUI

struct TeamSelectionView: View {
    @Binding var leftTeamPlayers: [User?]
    @Binding var rightTeamPlayers: [User?]
    @State private var selectedPosition: Int = 1
    @State private var selectedTeam: TeamSide = .left
    @State private var showingPlayerSelection = false
    @State private var availableUsers: [User] = []
    
    let onBack: () -> Void
    let onPlayerUpdated: ((User?, Int, Bool) -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            
            ScrollView {
                
                HStack(spacing: 8) {
                    VStack(spacing: 2) {
                        ForEach(1...7, id: \.self) { position in
                                let user = leftTeamPlayers[position - 1]
                                PlayerButton(
                                    user: user,
                                    position: position,
                                    team: .left,
                                    color: .blue
                                ) {
                                    selectedPosition = position
                                    selectedTeam = .left
                                    showingPlayerSelection = true
                                }
                        }
                    }
                    
                    VStack(spacing: 2) {
                        ForEach(1...7, id: \.self) { position in
                                let user = rightTeamPlayers[position - 1]
                                PlayerButton(
                                    user: user,
                                    position: position,
                                    team: .right,
                                    color: .red
                                ) {
                                    selectedPosition = position
                                    selectedTeam = .right
                                    showingPlayerSelection = true
                                }
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .onAppear {
            loadUsers()
        }
        .sheet(isPresented: $showingPlayerSelection) {
            PlayerSelectionView(
                availableUsers: availableUsers,
                mode: .teamSetup(position: selectedPosition, team: selectedTeam),
                onPlayerSelected: { selectedUser in
                    assignPlayerToPosition(user: selectedUser, position: selectedPosition, team: selectedTeam)
                    onPlayerUpdated?(selectedUser, selectedPosition, selectedTeam == .left)
                    showingPlayerSelection = false
                },
                leftTeamPlayers: leftTeamPlayers,
                rightTeamPlayers: rightTeamPlayers
            )
        }
    }
    
    private func loadUsers() {
        Task {
            do {
                let users = try await SupabaseService.shared.fetchUsers()
                await MainActor.run {
                    availableUsers = users
                    print("✅ Loaded \(users.count) users successfully")
                    for user in users {
                        print("User: \(user.displayName) (id: \(user.id ?? 0))")
                    }
                }
            } catch {
                print("❌ Failed to load users: \(error)")
            }
        }
    }
    
    private func assignPlayerToPosition(user: User?, position: Int, team: TeamSide) {
        let index = position - 1 // Convert to 0-based index
        if team == .left {
            leftTeamPlayers[index] = user
        } else {
            rightTeamPlayers[index] = user
        }
    }
}

struct PlayerButton: View {
    let user: User?
    let position: Int
    let team: TeamSide
    let color: Color
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Text("\(position)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .frame(width: 12)
                
                Text(user?.displayName ?? "-")
                    .font(.caption2)
                    .lineLimit(1)
                    .truncationMode(.tail)
                
                Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }
}
