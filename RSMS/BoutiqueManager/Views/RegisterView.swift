import SwiftUI

public struct RegisterView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @Environment(\.presentationMode) var presentationMode
    
    public init() {}
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                VStack(spacing: 10) {
                    Text("RSMS")
                        .font(.system(size: 40, weight: .bold, design: .serif))
                        .foregroundColor(BoutiqueTheme.primaryText)

                    Text("Register Boutique Manager")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(BoutiqueTheme.secondaryText)
                        .tracking(1.5)
                }
                .padding(.top, 40)
                .padding(.bottom, 20)

                VStack(spacing: 16) {
                    TextField(
                        "",
                        text: $authVM.name,
                        prompt: Text("Full Name").foregroundColor(BoutiqueTheme.mutedText)
                    )
                        .padding()
                        .foregroundColor(BoutiqueTheme.primaryText)
                        .background(BoutiqueTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.luxuryDivider, lineWidth: 0.8))
                        .autocapitalization(.words)

                    TextField(
                        "",
                        text: $authVM.email,
                        prompt: Text("Email").foregroundColor(BoutiqueTheme.mutedText)
                    )
                        .padding()
                        .foregroundColor(BoutiqueTheme.primaryText)
                        .background(BoutiqueTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.luxuryDivider, lineWidth: 0.8))
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    TextField(
                        "",
                        text: $authVM.phone,
                        prompt: Text("Phone Number (Optional)").foregroundColor(BoutiqueTheme.mutedText)
                    )
                        .padding()
                        .foregroundColor(BoutiqueTheme.primaryText)
                        .background(BoutiqueTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.luxuryDivider, lineWidth: 0.8))
                        .keyboardType(.phonePad)

                    SecureField(
                        "",
                        text: $authVM.password,
                        prompt: Text("Password").foregroundColor(BoutiqueTheme.mutedText)
                    )
                        .padding()
                        .foregroundColor(BoutiqueTheme.primaryText)
                        .background(BoutiqueTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.luxuryDivider, lineWidth: 0.8))
                }
                .padding(.horizontal, 40)

                if let error = authVM.errorMessage {
                    Text(error)
                        .foregroundColor(BoutiqueTheme.deepAccent)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }

                Button(action: {
                    authVM.register()
                }) {
                    if authVM.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .luxuryPrimaryButtonChrome(cornerRadius: 16)
                    } else {
                        Text("CREATE ACCOUNT")
                            .tracking(1.5)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .luxuryPrimaryButtonChrome(cornerRadius: 16)
                    }
                }
                .buttonStyle(LuxuryPressStyle())
                .padding(.horizontal, 40)
                .padding(.top, 10)
                .disabled(authVM.isLoading)

                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text("Already have an account? Sign In")
                        .font(.caption)
                        .foregroundColor(BoutiqueTheme.secondaryText)
                }
                .padding(.top, 20)
                
                Spacer(minLength: 40)
            }
        }
        .background(BoutiqueTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
    }
}
