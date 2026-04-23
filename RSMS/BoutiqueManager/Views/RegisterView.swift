import SwiftUI

public struct RegisterView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 10) {
                    Text("RSMS")
                        .font(.system(size: 40, weight: .light, design: .serif))
                        .foregroundColor(Theme.textPrimary)
                    
                    Text("Register Boutique Manager")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                        .tracking(1.5)
                }
                .padding(.top, 40)
                .padding(.bottom, 20)
                
                // Input Fields
                VStack(spacing: 16) {
                    TextField("Full Name", text: $authVM.name)
                        .padding()
                        .background(Color.appCard)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous).stroke(Color.appBorder, lineWidth: 1))
                        .autocapitalization(.words)
                    
                    TextField("Email", text: $authVM.email)
                        .padding()
                        .background(Color.appCard)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous).stroke(Color.appBorder, lineWidth: 1))
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        
                    TextField("Phone Number (Optional)", text: $authVM.phone)
                        .padding()
                        .background(Color.appCard)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous).stroke(Color.appBorder, lineWidth: 1))
                        .keyboardType(.phonePad)
                    
                    SecureField("Password", text: $authVM.password)
                        .padding()
                        .background(Color.appCard)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous).stroke(Color.appBorder, lineWidth: 1))
                }
                .padding(.horizontal, 40)
                
                if let error = authVM.errorMessage {
                    Text(error)
                        .foregroundColor(Theme.error)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                // Register Button
                Button(action: {
                    authVM.register()
                }) {
                    if authVM.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.offWhite))
                            .primaryButtonStyle()
                    } else {
                        Text("CREATE ACCOUNT")
                            .tracking(1.5)
                            .primaryButtonStyle()
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 10)
                .disabled(authVM.isLoading)
                
                // Back to Login
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Already have an account? Sign In")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
                }
                .padding(.top, 20)
                
                Spacer(minLength: 40)
            }
        }
        .background(Color.appBackground.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}
