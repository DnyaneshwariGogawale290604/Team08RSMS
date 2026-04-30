import SwiftUI

public struct LoginView: View {
    @ObservedObject var viewModel: SessionViewModel

    public init(viewModel: SessionViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            Color.luxuryBackground.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 30) {
                    Spacer(minLength: 50)

                    VStack(spacing: 12) {
                        Image(systemName: "cube.box.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.luxuryPrimary)
                        Text("RSMS")
                            .font(.system(size: 38, weight: .bold, design: .serif))
                            .foregroundColor(.luxuryPrimaryText)
                        Text("Retail Store Management System")
                            .font(.system(size: 14, weight: .regular, design: .default))
                            .foregroundColor(.luxurySecondaryText)
                            .tracking(0.5)
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 16) {
                        if viewModel.mfaRequired {
                            Text("A 6-digit verification code has been sent to your email. Please enter it below.")
                                .font(.subheadline)
                                .foregroundColor(.luxurySecondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.bottom, 8)

                            TextField(
                                "",
                                text: $viewModel.otpCode,
                                prompt: Text("Enter 6-digit OTP").foregroundColor(.luxuryMutedText)
                            )
                                .keyboardType(.numberPad)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .foregroundColor(.luxuryPrimaryText)
                                .padding()
                                .background(Color.luxurySurface)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.luxuryDivider, lineWidth: 0.8))
                        } else {
                            TextField(
                                "",
                                text: $viewModel.email,
                                prompt: Text("Email Address").foregroundColor(.luxuryMutedText)
                            )
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .foregroundColor(.luxuryPrimaryText)
                                .padding()
                                .background(Color.luxurySurface)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.luxuryDivider, lineWidth: 0.8))

                            SecureField(
                                "",
                                text: $viewModel.password,
                                prompt: Text("Password").foregroundColor(.luxuryMutedText)
                            )
                                .foregroundColor(.luxuryPrimaryText)
                                .padding()
                                .background(Color.luxurySurface)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.luxuryDivider, lineWidth: 0.8))
                        }
                    }
                    .padding(.horizontal, 32)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundColor(.luxuryDeepAccent)
                            .padding(.horizontal, 32)
                            .multilineTextAlignment(.center)
                    }

                    Button(action: {
                        Task {
                            if viewModel.mfaRequired {
                                await viewModel.submitOTP()
                            } else {
                                await viewModel.signIn()
                            }
                        }
                    }) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text(viewModel.mfaRequired ? "Verify OTP" : "Log In")
                                    .font(.system(size: 16, weight: .semibold, design: .default))
                                    .tracking(0.3)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .luxuryPrimaryButtonChrome(
                            enabled: !viewModel.isLoading &&
                                (viewModel.mfaRequired ? !viewModel.otpCode.isEmpty : (!viewModel.email.isEmpty && !viewModel.password.isEmpty)),
                            cornerRadius: 16
                        )
                    }
                    .buttonStyle(LuxuryPressStyle())
                    .disabled(viewModel.isLoading || 
                             (viewModel.mfaRequired ? viewModel.otpCode.isEmpty : (viewModel.email.isEmpty || viewModel.password.isEmpty)))
                    .padding(.horizontal, 32)

                    if !viewModel.mfaRequired {
                        Button(action: {
                            Task { await viewModel.devBypassSignIn() }
                        }) {
                            Text("Dev Bypass (No OTP)")
                                .font(.system(size: 16, weight: .semibold, design: .default))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.luxurySurface)
                                .foregroundColor(.luxuryDeepAccent)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(LuxuryPressStyle())
                        .disabled(viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)
                        .padding(.horizontal, 32)
                        .padding(.top, -8)
                    }
                    
                    if viewModel.mfaRequired {
                        Button("Cancel") {
                            Task { await viewModel.signOut() }
                        }
                        .font(.footnote)
                        .foregroundColor(.luxurySecondaryText)
                        .padding(.top, 8)
                    }

                    Spacer()
                }
            }
        }
        .dismissKeyboardOnTap()
    }
}
