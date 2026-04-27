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
                        .foregroundColor(BoutiqueTheme.primaryText)

                    Text("Boutique Manager Login")
                        .font(.system(size: 14, weight: .regular, design: .default))
                        .foregroundColor(BoutiqueTheme.secondaryText)
                        .tracking(1.2)
                }
                .padding(.bottom, 40)

                VStack(spacing: 20) {
                    TextField(
                        "",
                        text: $authVM.email,
                        prompt: Text("Email").foregroundColor(BoutiqueTheme.mutedText)
                    )
                        .padding()
                        .background(BoutiqueTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(BoutiqueTheme.divider, lineWidth: 1)
                        )
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField(
                        "",
                        text: $authVM.password,
                        prompt: Text("Password").foregroundColor(BoutiqueTheme.mutedText)
                    )
                        .padding()
                        .background(BoutiqueTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(BoutiqueTheme.divider, lineWidth: 1)
                        )
                }
                .padding(.horizontal, 40)

                if let error = authVM.errorMessage {
                    Text(error)
                        .foregroundColor(BoutiqueTheme.deepAccent)
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
                            .boutiquePrimaryButtonChrome(enabled: !authVM.isLoading)
                    } else {
                        Text("SIGN IN")
                            .tracking(1.5)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .boutiquePrimaryButtonChrome()
                    }
                }
                .buttonStyle(LuxuryPressStyle())
                .padding(.horizontal, 40)
                .padding(.top, 20)
                .disabled(authVM.isLoading)

                NavigationLink(destination: RegisterView()) {
                    Text("Don't have an account? Register")
                        .font(.caption)
                        .foregroundColor(BoutiqueTheme.secondaryText)
                }
                .padding(.top, 20)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(BoutiqueTheme.background.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }
}
