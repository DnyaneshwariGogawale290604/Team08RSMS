import Foundation
import Combine
import Supabase

@MainActor
public final class SessionViewModel: ObservableObject {
    @Published public var email = ""
    @Published public var password = ""
    @Published public var otpCode = ""
    @Published public var mfaRequired = false
    @Published public var role: AppRole?
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    // Add a property to hold the generated OTP locally
    private var generatedOTP: String?

    private let client = SupabaseManager.shared.client
    private let roleService = RoleService.shared

    public init() {}

    public func restoreSession() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await client.auth.session
            try await assignRole(for: session.user.id)
            errorMessage = nil
            mfaRequired = false
        } catch {
            role = nil
        }
    }

    public func signIn() async {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter your email."
            return
        }

        guard !password.isEmpty else {
            errorMessage = "Please enter your password."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let _ = try await client.auth.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )

            // Password is correct. We sign out to invalidate this initial session 
            // since we require OTP to actually access the app.
            try? await client.auth.signOut()
            
            // Trigger custom Resend OTP
            let newOtp = String(format: "%06d", Int.random(in: 100000...999999))
            self.generatedOTP = newOtp
            
            try await AuthService.shared.sendResendOTP(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines), 
                otp: newOtp
            )

            errorMessage = nil
            mfaRequired = true // Transition UI
        } catch {
            role = nil
            errorMessage = error.localizedDescription
        }
    }

    public func submitOTP() async {
        guard !otpCode.isEmpty else {
            errorMessage = "Please enter the 6-digit OTP code."
            return
        }

        isLoading = true
        defer { isLoading = false }

        // Verify the OTP code locally
        guard otpCode.trimmingCharacters(in: .whitespacesAndNewlines) == self.generatedOTP else {
            errorMessage = "Invalid or expired OTP code."
            return
        }

        do {
            // Re-authenticate silently to actually get a session since the OTP was correct
            let session = try await client.auth.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            
            try await assignRole(for: session.user.id)
            
            errorMessage = nil
            password = ""
            otpCode = ""
            self.generatedOTP = nil
            mfaRequired = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func devBypassSignIn() async {
        guard !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Please enter your email."
            return
        }

        guard !password.isEmpty else {
            errorMessage = "Please enter your password."
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let session = try await client.auth.signIn(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                password: password
            )
            
            try await assignRole(for: session.user.id)
            
            errorMessage = nil
            password = ""
            otpCode = ""
            self.generatedOTP = nil
            mfaRequired = false
        } catch {
            role = nil
            errorMessage = error.localizedDescription
        }
    }

    public func signOut() async {
        do {
            try await client.auth.signOut()
        } catch {
            errorMessage = error.localizedDescription
        }

        role = nil
        password = ""
        otpCode = ""
        mfaRequired = false
    }

    private func assignRole(for userId: UUID) async throws {
        guard let resolvedRole = try await roleService.resolveRole(for: userId) else {
            try? await client.auth.signOut()
            role = nil
            throw SessionError.roleNotAssigned
        }

        role = resolvedRole
    }
}

public enum SessionError: LocalizedError {
    case roleNotAssigned

    public var errorDescription: String? {
        switch self {
        case .roleNotAssigned:
            return "No role is assigned for this user. Contact your administrator."
        }
    }
}
