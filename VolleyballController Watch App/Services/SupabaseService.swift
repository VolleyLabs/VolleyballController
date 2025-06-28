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
    
    func testConnection() async throws -> Bool {
        do {
            // Test connection by querying existing daily_totals table with minimal data
            let _ = try await client
                .from("daily_totals")
                .select("day")
                .limit(1)
                .execute()
            
            return true
        } catch {
            // Log the specific error for debugging
            print("Supabase connection test error: \(error)")
            throw error
        }
    }
}