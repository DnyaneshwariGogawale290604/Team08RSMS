import Foundation
import Supabase
import PostgREST

enum SupabaseConfiguration {
    static let projectURL = URL(string: "https://ionszphvxhffqfwlohiv.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlvbnN6cGh2eGhmZnFmd2xvaGl2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzYzMTMyNzQsImV4cCI6MjA5MTg4OTI3NH0.KYYW_eEJIBJQB1-7fvxUo7N4GCxN9PzpROZQoef0xh0"
    static let serviceRoleKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlvbnN6cGh2eGhmZnFmd2xvaGl2Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc3NjMxMzI3NCwiZXhwIjoyMDkxODg5Mjc0fQ.zjJiPnQukevYfyz_CFveLmyHt0jykQWoolEORej233U"

    static var publicKey: String {
        ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? anonKey
    }
}

public final class SupabaseManager: @unchecked Sendable {
    public static let shared = SupabaseManager()

    public let client: SupabaseClient
    public let serviceRoleClient: SupabaseClient

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
