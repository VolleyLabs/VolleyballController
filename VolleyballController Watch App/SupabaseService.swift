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
        // Simple test: just try to create a basic request to test connectivity
        do {
            // Test with a simple REST API call using modern API
            let _ = try await client
                .from("_health")
                .select("*")
                .limit(1)
                .execute()
            
            return true
        } catch {
            // Log the specific error for debugging
            print("Supabase connection test error: \(error)")
            
            // Check if this is a "table not found" error (which means connection works)
            let errorString = error.localizedDescription.lowercased()
            if errorString.contains("does not exist") || errorString.contains("not found") {
                // Connection works, just no _health table (which is expected)
                return true
            }
            
            throw error
        }
    }
}