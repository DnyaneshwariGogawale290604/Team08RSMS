import Foundation
import Supabase
import PostgREST

public actor AuthService {
    public static let shared = AuthService()
    private let client = SupabaseManager.shared.client

    private init() {}

    public func login(email: String, password: String) async throws -> User {
        // Attempt Supabase Auth
        let session = try await client.auth.signIn(email: email, password: password)
        
        do {
            // Fetch custom user profile from `users` table
            let user: User = try await client
                .from("users")
                .select()
                .eq("user_id", value: session.user.id)
                .single()
                .execute()
                .value
            return user
        } catch {
            print("Error fetching user profile: \(error)")
            // If the user profile doesn't exist yet, we can return a fallback to allow login
            return User(id: session.user.id, name: email, email: email, phone: nil, brandId: nil)
        }
    }

    /// Send OTP after password authentication using Resend API directly
    public func sendResendOTP(email: String, otp: String) async throws {
        let url = URL(string: "https://api.resend.com/emails")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let resendApiKey = "re_fM2oErnB_JyFUL4UCBuhsQFotqmLqQwD8"
        
        request.setValue("Bearer \(resendApiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "from": "RSMS Security <onboarding@resend.dev>",
            "to": [email],
            "subject": "Your RSMS Verification Code",
            "html": """
            <div style="font-family: sans-serif; padding: 20px;">
                <h2>RSMS Authentication</h2>
                <p>Your secure verification code is:</p>
                <h1 style="color: #333; letter-spacing: 2px;">\(otp)</h1>
                <p>Please enter this code in the app to complete your login.</p>
            </div>
            """
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        let httpResponse = response as? HTTPURLResponse
        guard let statusCode = httpResponse?.statusCode,
              (200...299).contains(statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown Resend error"
            print("Resend Error: \(errorMsg)")
            
            var displayMessage = "Failed to send OTP via Resend."
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let message = json["message"] as? String {
                displayMessage = message
            }
            
            throw NSError(domain: "Resend", code: httpResponse?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: displayMessage])
        }
    }
    
    /// Send a welcome email to newly created staff with their login credentials
    public func sendWelcomeEmail(email: String, name: String, password: String, role: String) async throws {
        let url = URL(string: "https://api.resend.com/emails")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let resendApiKey = "re_fM2oErnB_JyFUL4UCBuhsQFotqmLqQwD8"
        request.setValue("Bearer \(resendApiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "from": "RSMS Security <onboarding@resend.dev>",
            "to": [email],
            "subject": "Welcome to RSMS — Your Account is Ready",
            "html": """
            <div style="font-family: sans-serif; padding: 20px; max-width: 500px;">
                <h2 style="color: #333;">Welcome to RSMS, \(name)!</h2>
                <p>Your <strong>\(role)</strong> account has been created.</p>
                <div style="background: #f5f5f5; padding: 16px; border-radius: 8px; margin: 16px 0;">
                    <p style="margin: 4px 0;"><strong>Email:</strong> \(email)</p>
                    <p style="margin: 4px 0;"><strong>Temporary Password:</strong> \(password)</p>
                </div>
                <p>When you log in, you will receive a <strong>6-digit OTP</strong> for multi-factor authentication.</p>
                <p style="color: #888; font-size: 12px;">Please change your password after your first login.</p>
            </div>
            """
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        let httpResponse = response as? HTTPURLResponse
        guard let statusCode = httpResponse?.statusCode,
              (200...299).contains(statusCode) else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown Resend error"
            print("Resend Welcome Email Error: \(errorMsg)")
            return
        }
        
        print("Welcome email sent successfully to \(email)")
    }

    public func register(email: String, password: String, name: String, phone: String) async throws -> User {
        // Attempt Supabase Registration
        let response = try await client.auth.signUp(email: email, password: password)
        let userId = response.user.id
        
        // Form the User profile
        let newUser = User(id: userId, name: name, email: email, phone: phone, brandId: nil)
        
        // Insert into public.users
        try await client
            .from("users")
            .insert(newUser)
            .execute()
            
        return newUser
    }

    /// Creates a new staff member: registers in Auth + inserts profile into users table + inserts into sales_associates
    public func registerStaff(email: String, password: String, name: String, phone: String?, salesTarget: Double?, initialRating: Double?) async throws {
        // Find current manager's session
        guard let sessionUser = try? await client.auth.session.user else { throw URLError(.userAuthenticationRequired) }
        let currentUserId = sessionUser.id
        
        // Find current manager's store ID
        struct BoutiqueManagerRecord: Decodable {
            let store_id: UUID
            let user_id: UUID
        }
        let managerRecords: [BoutiqueManagerRecord] = try await client
            .from("boutique_managers")
            .select()
            .eq("user_id", value: currentUserId.uuidString)
            .execute()
            .value
            
        let actualStoreId: String
        let actualManagerId: String
        
        if let record = managerRecords.first {
            actualStoreId = record.store_id.uuidString
            actualManagerId = record.user_id.uuidString
        } else {
            // Fallback for testing: if the user isn't formally a manager in the DB, 
            // fallback to real Zara Mumbai manager to avoid foreign-key crash.
            let anyManagers: [BoutiqueManagerRecord] = try await client
                .from("boutique_managers")
                .select()
                .limit(1)
                .execute()
                .value
            
            guard let fallback = anyManagers.first else {
                throw NSError(domain: "AuthService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No boutique managers configured in database."])
            }
            actualStoreId = fallback.store_id.uuidString
            actualManagerId = fallback.user_id.uuidString
        }
        
        // Use the password provided by the boutique manager
        let response = try await client.auth.signUp(email: email, password: password)
        let newUserId = response.user.id

        struct UserInsert: Encodable {
            let user_id: String
            let name: String
            let email: String
            let phone: String?
        }
        let userPayload = UserInsert(user_id: newUserId.uuidString, name: name, email: email, phone: phone)
        try await client
            .from("users")
            .insert(userPayload)
            .execute()
            
        struct SalesAssociateInsert: Encodable {
            let user_id: String
            let store_id: String
            let boutique_manager_id: String
        }
        let saPayload = SalesAssociateInsert(
            user_id: newUserId.uuidString,
            store_id: actualStoreId,
            boutique_manager_id: actualManagerId
        )
        try await client
            .from("sales_associates")
            .insert(saPayload)
            .execute()

        // Seed an initial sales_metrics row if a target or rating was provided
        if let target = salesTarget, target > 0 {
            struct SalesMetricsInsert: Encodable {
                let sales_associate_id: String
                let date: String
                let total_sales_amount: Double
                let target_amount: Double
                let number_of_orders: Int
            }
            let today = ISO8601DateFormatter().string(from: Date()).prefix(10).description
            let metricsPayload = SalesMetricsInsert(
                sales_associate_id: newUserId.uuidString,
                date: today,
                total_sales_amount: initialRating ?? 0,
                target_amount: target,
                number_of_orders: 0
            )
            try? await client
                .from("sales_metrics")
                .insert(metricsPayload)
                .execute()
        }
        
        // Send welcome email to the new staff member via Resend
        try? await sendWelcomeEmail(
            email: email,
            name: name,
            password: password,
            role: "Sales Associate"
        )
    }

    public func getCurrentUser() async throws -> User? {
        guard let sessionUser = try? await client.auth.session.user else { return nil }
        
        let user: User = try await client
            .from("users")
            .select()
            .eq("user_id", value: sessionUser.id.uuidString)
            .single()
            .execute()
            .value
            
        return user
    }
    
    public func updatePassword(newPassword: String) async throws {
        try await client.auth.update(user: UserAttributes(password: newPassword))
    }
    
    public func logout() async throws {
        try await client.auth.signOut()
    }
}
