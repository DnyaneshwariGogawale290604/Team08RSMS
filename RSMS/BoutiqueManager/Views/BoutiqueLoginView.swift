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
                        .font(.system(size: 40, weight: .light, design: .serif))
                        .foregroundColor(Theme.textPrimary)

                    Text("Boutique Manager Login")
                        .font(.subheadline)
                        .foregroundColor(Theme.textSecondary)
                        .tracking(2)
                }
                .padding(.bottom, 40)

                VStack(spacing: 20) {
                    TextField("Email", text: $authVM.email)
                        .padding()
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous)
                                .stroke(CatalogTheme.divider, lineWidth: 1)
                        )
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField("Password", text: $authVM.password)
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
                        .foregroundColor(Theme.error)
                        .font(.caption)
                }

                Button(action: {
                    authVM.login()
                }) {
                    if authVM.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: Theme.offWhite))
                            .primaryButtonStyle()
                    } else {
                        Text("SIGN IN")
                            .tracking(1.5)
                            .primaryButtonStyle()
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 20)
                .disabled(authVM.isLoading)

                NavigationLink(destination: RegisterView()) {
                    Text("Don't have an account? Register")
                        .font(.caption)
                        .foregroundColor(Theme.textSecondary)
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
