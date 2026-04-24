import SwiftUI

public struct BoutiqueLoginView: View {
    @EnvironmentObject var authVM: AuthViewModel

    public init() {}

    public var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()

                VStack(spacing: 10) {
                    Text("RSMS")
                        .font(.system(size: 40, weight: .bold, design: .serif))
                        .foregroundColor(.luxuryPrimaryText)

                    Text("Boutique Manager Login")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(.luxurySecondaryText)
                        .tracking(1.2)
                }
                .padding(.bottom, 40)

                VStack(spacing: 20) {
                    TextField(
                        "",
                        text: $authVM.email,
                        prompt: Text("Email").foregroundColor(.luxuryMutedText)
                    )
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous)
                                .stroke(CatalogTheme.divider, lineWidth: 1)
                        )
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField(
                        "",
                        text: $authVM.password,
                        prompt: Text("Password").foregroundColor(.luxuryMutedText)
                    )
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous)
                                .stroke(CatalogTheme.divider, lineWidth: 1)
                        )
                }
                .padding(.horizontal, 40)

                if let error = authVM.errorMessage {
                    Text(error)
                        .foregroundColor(.luxuryDeepAccent)
                        .font(.caption)
                }

                Button(action: {
                    authVM.login()
                }) {
                    if authVM.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .luxuryPrimaryButtonChrome(cornerRadius: 16)
                    } else {
                        Text("SIGN IN")
                            .tracking(1.5)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .luxuryPrimaryButtonChrome(cornerRadius: 16)
                    }
                }
                .buttonStyle(LuxuryPressStyle())
                .padding(.horizontal, 40)
                .padding(.top, 20)
                .disabled(authVM.isLoading)

                NavigationLink(destination: RegisterView()) {
                    Text("Don't have an account? Register")
                        .font(.caption)
                        .foregroundColor(.luxurySecondaryText)
                }
                .padding(.top, 20)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(CatalogTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }
}
