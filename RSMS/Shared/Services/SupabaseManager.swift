import Foundation
import Supabase
import PostgREST

enum SupabaseConfiguration {
    static let projectURL = URL(string: "https://ionszphvxhffqfwlohiv.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlvbnN6cGh2eGhmZnFmd2xvaGl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYzMTMyNzQsImV4cCI6MjA5MTg4OTI3NH0.KYYW_eEJIBJQB1-7fvxUo7N4GCxN9PzpROZQoef0xh0"
    static let serviceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlvbnN6cGh2eGhmZnFmd2xvaGl2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjMxMzI3NCwiZXhwIjoyMDkxODg5Mjc0fQ.zjJiPnQukevYfyz_CFveLmyHt0jykQWoolEORej233U"
    
    // Courier Simulator (Project B)
    static let courierSimulatorURL = "https://yhrkthushductbplnxjq.supabase.co/functions/v1"
    static let courierSimulatorAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inlocmt0aHVzaGR1Y3RicGxueGpxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc0MzY5MzcsImV4cCI6MjA5MzAxMjkzN30.9IvavsCYDg6WPhUU2uXiAorALx9OFv9xKVzGObHQjIA"

    static var publicKey: String {
        ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? anonKey
    }
}

public final class SupabaseManager: @unchecked Sendable {
    nonisolated(unsafe) public static let shared = SupabaseManager()

    nonisolated(unsafe) public let client: SupabaseClient
    nonisolated(unsafe) public let serviceRoleClient: SupabaseClient

    private init() {
        self.client = SupabaseClient(
            supabaseURL: SupabaseConfiguration.projectURL,
            supabaseKey: SupabaseConfiguration.publicKey
        )
        self.serviceRoleClient = SupabaseClient(
            supabaseURL: SupabaseConfiguration.projectURL,
            supabaseKey: SupabaseConfiguration.serviceRoleKey
        )
    }
}
