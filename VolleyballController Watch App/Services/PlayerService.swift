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
    func findUser(by id: Int64) -> User? {
        return cachedPlayers.first { $0.id == id }
    }
    
    /// Get players sorted by name
    func getPlayersSortedByName() -> [User] {
        return cachedPlayers.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
    
    /// Get players sorted by total points today (descending) within a team
    func getPlayersSortedByPoints(isLeft: Bool, teamPlayers: [User?], pointsHistory: [Point]) -> [User] {
        let teamPlayers = getTeamPlayers(isLeft: isLeft, teamPlayers: teamPlayers)
        let otherPlayers = cachedPlayers.filter { player in
            !teamPlayers.contains { $0.id == player.id }
        }
        
        // Calculate points for each team player
        let playerPointCounts = calculatePlayerPoints(from: pointsHistory)
        
        // Sort team players by points (highest first), then by name
        let sortedTeamPlayers = teamPlayers.sorted { player1, player2 in
            let points1 = playerPointCounts[player1.id ?? -1] ?? 0
            let points2 = playerPointCounts[player2.id ?? -1] ?? 0
            
            if points1 != points2 {
                return points1 > points2  // Higher points first
            }
            return player1.displayName.localizedCaseInsensitiveCompare(player2.displayName) == .orderedAscending  // Then alphabetically
        }
        
        // Sort other players by name
        let sortedOtherPlayers = otherPlayers.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        
        return sortedTeamPlayers + sortedOtherPlayers
    }
    
    /// Calculate total points scored by each player today
    private func calculatePlayerPoints(from pointsHistory: [Point]) -> [Int64: Int] {
        var playerPoints: [Int64: Int] = [:]
        
        for point in pointsHistory {
            if let playerId = point.playerId {
                playerPoints[playerId, default: 0] += 1
            }
        }
        
        return playerPoints
    }
}