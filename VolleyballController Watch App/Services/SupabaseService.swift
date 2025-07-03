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
        let defaultAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6" +
                            "InVmZWpvY2VsYnZydmdtb2V3aGF3Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDE2NTU4" +
                            "NDksImV4cCI6MjA1NzIzMTg0OX0.HoZLb6kO9m3Mt23VCTkdLUTJZM-5HJG3jiRajDcufDM"
        let anonKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String
                     ?? defaultAnonKey

        client = SupabaseClient(
            supabaseURL: URL(string: url)!,
            supabaseKey: anonKey
        )
    }

    func addPoint(_ point: Point) async throws {
        do {
            try await client
                .from("points")
                .insert(point, returning: .minimal)
                .execute()

            #if DEBUG
            print("[Supabase] ✅ points insert OK")
            #endif
        } catch {
            #if DEBUG
            print("[Supabase] ❌ points insert FAILED:", error)
            #endif
            throw error
        }
    }

    func fetchTodaysPoints() async throws -> [Point] {
        do {
            let today = ISO8601DateFormatter().string(from: Date()).prefix(10)

            let points: [Point] = try await client
                .from("points")
                .select("*")
                .gte("created_at", value: "\(today)T00:00:00Z")
                .lt("created_at", value: "\(today)T23:59:59Z")
                .order("created_at", ascending: true)
                .execute()
                .value

            #if DEBUG
            print("[Supabase] ✅ points fetch OK - found \(points.count) records " +
                  "for today (\(today))")
            #endif

            return points
        } catch {
            #if DEBUG
            print("[Supabase] ❌ points fetch FAILED:", error)
            #endif
            throw error
        }
    }

    func deleteLastPoint() async throws -> Point? {
        do {
            // First, get the most recent point
            let recentPoints: [Point] = try await client
                .from("points")
                .select("*")
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value

            guard let lastPoint = recentPoints.first, let pointId = lastPoint.id else {
                #if DEBUG
                print("[Supabase] ⚠️ No points found to delete")
                #endif
                return nil
            }

            // Delete the point
            try await client
                .from("points")
                .delete()
                .eq("id", value: pointId)
                .execute()

            #if DEBUG
            print("[Supabase] ✅ Last point deleted successfully")
            #endif

            return lastPoint
        } catch {
            #if DEBUG
            print("[Supabase] ❌ Delete last point FAILED:", error)
            #endif
            throw error
        }
    }

    func deleteSpecificPoint(_ point: Point) async throws {
        do {
            guard let pointId = point.id else {
                let errorMessage = "Point ID is required for deletion"
                throw NSError(domain: "SupabaseService", code: 400,
                             userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }

            try await client
                .from("points")
                .delete()
                .eq("id", value: pointId)
                .execute()

            #if DEBUG
            print("[Supabase] ✅ Specific point deleted successfully: \(pointId)")
            #endif
        } catch {
            #if DEBUG
            print("[Supabase] ❌ Delete specific point FAILED:", error)
            #endif
            throw error
        }
    }

    func deleteAllTodaysPoints() async throws {
        do {
            let today = ISO8601DateFormatter().string(from: Date()).prefix(10)

            try await client
                .from("points")
                .delete()
                .gte("created_at", value: "\(today)T00:00:00Z")
                .lt("created_at", value: "\(today)T23:59:59Z")
                .execute()

            #if DEBUG
            print("[Supabase] ✅ All today's points deleted successfully")
            #endif
        } catch {
            #if DEBUG
            print("[Supabase] ❌ Delete all points FAILED:", error)
            #endif
            throw error
        }
    }

}
