import Foundation
import SwiftUI

@Observable
class PlayerService {
    static let shared = PlayerService()
    
    private var cachedPlayers: [User] = []
    private var isLoading = false
    private var lastLoadTime: Date?
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    private init() {}
    
    var players: [User] {
        return cachedPlayers
    }
    
    var isPlayersLoaded: Bool {
        return !cachedPlayers.isEmpty
    }
    
    /// Load players in parallel during app initialization
    func loadPlayersAsync() async {
        // Prevent multiple simultaneous loads
        guard !isLoading else { return }
        
        // Check if cache is still valid
        if let lastLoad = lastLoadTime,
           Date().timeIntervalSince(lastLoad) < cacheTimeout,
           !cachedPlayers.isEmpty {
            return
        }
        
        isLoading = true
        
        do {
            let players = try await SupabaseService.shared.fetchUsers()
            
            await MainActor.run {
                self.cachedPlayers = players
                self.lastLoadTime = Date()
                self.isLoading = false
                
                #if DEBUG
                print("[PlayerService] ✅ Players loaded and cached: \(players.count) players")
                #endif
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
                
                #if DEBUG
                print("[PlayerService] ❌ Failed to load players: \(error)")
                #endif
            }
        }
    }
    
    /// Force refresh players from server
    func refreshPlayers() async {
        lastLoadTime = nil
        await loadPlayersAsync()
    }
    
    /// Get players filtered by team (left or right)
    func getTeamPlayers(isLeft: Bool, teamPlayers: [User?]) -> [User] {
        let teamUserIds = Set(teamPlayers.compactMap { $0?.id })
        return cachedPlayers.filter { teamUserIds.contains($0.id ?? -1) }
    }
    
    /// Get players not on any team
    func getAvailablePlayers(leftTeam: [User?], rightTeam: [User?]) -> [User] {
        let usedPlayerIds = Set((leftTeam + rightTeam).compactMap { $0?.id })
        return cachedPlayers.filter { !usedPlayerIds.contains($0.id ?? -1) }
    }
    
    /// Get players for point attribution (prioritize team players)
    func getPlayersForPointAttribution(isLeft: Bool, teamPlayers: [User?]) -> [User] {
        let teamPlayers = getTeamPlayers(isLeft: isLeft, teamPlayers: teamPlayers)
        let otherPlayers = cachedPlayers.filter { player in
            !teamPlayers.contains { $0.id == player.id }
        }
        
        return teamPlayers + otherPlayers
    }
    
    /// Find user by ID
    func findUser(by id: Int) -> User? {
        return cachedPlayers.first { $0.id == id }
    }
    
    /// Get players sorted by name
    func getPlayersSortedByName() -> [User] {
        return cachedPlayers.sorted { $0.displayName < $1.displayName }
    }
}