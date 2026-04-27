import SwiftUI

public struct ChangePasswordView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var authVM: AuthViewModel
    
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?
    @State private var isLoading = false
    
    public init() {}
    
    public var body: some View {
        Form {
            Section(header: Text("Update Password")) {
                SecureField("New Password", text: $newPassword)
                SecureField("Confirm Password", text: $confirmPassword)
            }
            
            if let error = errorMessage {
                Section {
                    Text(error)
                        .foregroundColor(BoutiqueTheme.error)
                        .font(.caption)
                }
            }
            
            Section {
                Button(action: updatePassword) {
                    if isLoading {
                        ProgressView()
                    } else {
                        Text("Save Password")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .appPrimaryButtonChrome(enabled: !newPassword.isEmpty && !confirmPassword.isEmpty)
                    }
                }
                .disabled(isLoading)
            }
        }
        .scrollContentBackground(.hidden)
        .navigationTitle("Change Password")
        .background(BoutiqueTheme.background.ignoresSafeArea())
        .tint(.appAccent)
    }
    
    private func updatePassword() {
        guard newPassword == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }
        guard newPassword.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                try await AuthService.shared.updatePassword(newPassword: newPassword)
                self.isLoading = false
                presentationMode.wrappedValue.dismiss()
            } catch {
                self.errorMessage = "Failed to update password."
                self.isLoading = false
            }
        }
    }
}
