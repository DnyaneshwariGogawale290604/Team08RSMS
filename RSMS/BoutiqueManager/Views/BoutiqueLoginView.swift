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
                        .foregroundColor(.luxuryPrimaryText)
                        .background(Color.luxurySurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.luxuryDivider, lineWidth: 0.8)
                        )
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)

                    SecureField(
                        "",
                        text: $authVM.password,
                        prompt: Text("Password").foregroundColor(.luxuryMutedText)
                    )
                        .padding()
                        .foregroundColor(.luxuryPrimaryText)
                        .background(Color.luxurySurface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.luxuryDivider, lineWidth: 0.8)
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
            .background(Color.luxuryBackground.ignoresSafeArea())
            .navigationBarHidden(true)
        }
    }
}
