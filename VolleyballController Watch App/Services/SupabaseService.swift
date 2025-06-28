import Foundation
import Supabase

class SupabaseService: ObservableObject {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    
    private init() {
        // For xcconfig files, we need to add these to Info.plist via build settings
        // Add these to your Info.plist preprocessing:
        // SUPABASE_URL = $(SUPABASE_URL)
        // SUPABASE_ANON_KEY = $(SUPABASE_ANON_KEY)
        
        let url = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String
                  ?? "https://ufejocelbvrvgmoewhaw.supabase.co"
        let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
                     ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVmZWpvY2VsYnZydmdtb2V3aGF3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE2NTU4NDksImV4cCI6MjA1NzIzMTg0OX0.HoZLb6kO9m3Mt23VCTkdLUTJZM-5HJG3jiRajDcufDM"
        
        client = SupabaseClient(
            supabaseURL: URL(string: url)!,
            supabaseKey: anonKey
        )
    }
    
    func fetchTodaysSetScore() async throws -> SetScore? {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10).description
        
        do {
            let scores: [SetScore] = try await client
                .from("daily_sets")
                .select("*")
                .eq("day", value: today)
                .limit(1)
                .execute()
                .value
            
            #if DEBUG
            print("[Supabase] ✅ daily_sets fetch OK - found \(scores.count) records")
            #endif
            
            return scores.first
        } catch {
            #if DEBUG
            print("[Supabase] ❌ daily_sets fetch FAILED:", error)
            #endif
            throw error
        }
    }
    
    func fetchTodaysGlobalScore() async throws -> GlobalScore? {
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10).description
        
        do {
            let scores: [GlobalScore] = try await client
                .from("daily_totals")
                .select("*")
                .eq("day", value: today)
                .limit(1)
                .execute()
                .value
            
            #if DEBUG
            print("[Supabase] ✅ daily_totals fetch OK - found \(scores.count) records")
            #endif
            
            return scores.first
        } catch {
            #if DEBUG
            print("[Supabase] ❌ daily_totals fetch FAILED:", error)
            #endif
            throw error
        }
    }
    
    func syncSetScore(_ setScore: SetScore) async throws {
        do {
            try await client
                .from("daily_sets")
                .upsert(setScore,
                        onConflict: "day",
                        returning: .minimal)
                .execute()
            
            #if DEBUG
            print("[Supabase] ✅ daily_sets upsert OK")
            #endif
        } catch {
            #if DEBUG
            print("[Supabase] ❌ daily_sets upsert FAILED:", error)
            #endif
            throw error
        }
    }
    
    func syncGlobalScore(_ globalScore: GlobalScore) async throws {
        do {
            try await client
                .from("daily_totals")
                .upsert(globalScore,
                        onConflict: "day", 
                        returning: .minimal)
                .execute()
            
            #if DEBUG
            print("[Supabase] ✅ daily_totals upsert OK")
            #endif
        } catch {
            #if DEBUG
            print("[Supabase] ❌ daily_totals upsert FAILED:", error)
            #endif
            throw error
        }
    }
}