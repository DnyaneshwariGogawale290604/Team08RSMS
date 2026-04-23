import SwiftUI

public struct LoginView: View {
    @ObservedObject var viewModel: SessionViewModel

    public init(viewModel: SessionViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 30) {
                Spacer()

                // Logo/Header
                VStack(spacing: 12) {
                    Image(systemName: "cube.box.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.appAccent)
                    Text("RSMS")
                        .font(.largeTitle.bold())
                        .foregroundColor(.appPrimaryText)
                    Text("Retail Store Management System")
                        .font(.subheadline)
                        .foregroundColor(.appSecondaryText)
                        .multilineTextAlignment(.center)
                }

                // Form
                VStack(spacing: 16) {
                    if viewModel.mfaRequired {
                        Text("A 6-digit verification code has been sent to your email. Please enter it below.")
                            .font(.subheadline)
                            .foregroundColor(.appSecondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 8)

                        TextField("Enter 6-digit OTP", text: $viewModel.otpCode)
                            .keyboardType(.numberPad)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding()
                            .background(Color.appCard)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous).stroke(Color.appBorder, lineWidth: 1))
                    } else {
                        TextField("Email Address", text: $viewModel.email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .padding()
                            .background(Color.appCard)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous).stroke(Color.appBorder, lineWidth: 1))

                        SecureField("Password", text: $viewModel.password)
                            .padding()
                            .background(Color.appCard)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous).stroke(Color.appBorder, lineWidth: 1))
                    }
                }
                .padding(.horizontal, 32)

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.footnote)
                        .foregroundColor(.red)
                        .padding(.horizontal, 32)
                        .multilineTextAlignment(.center)
                }

                // Login Button
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
                            Text(viewModel.mfaRequired ? "Verify OTP" : "Log In").font(.headline)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .appPrimaryButtonChrome(enabled: !viewModel.isLoading && 
                                          (viewModel.mfaRequired ? !viewModel.otpCode.isEmpty : (!viewModel.email.isEmpty && !viewModel.password.isEmpty)))
                }
                .disabled(viewModel.isLoading || 
                         (viewModel.mfaRequired ? viewModel.otpCode.isEmpty : (viewModel.email.isEmpty || viewModel.password.isEmpty)))
                .padding(.horizontal, 32)
                
                // Dev Bypass Button
                if !viewModel.mfaRequired {
                    Button(action: {
                        Task { await viewModel.devBypassSignIn() }
                    }) {
                        Text("Dev Bypass (No OTP)")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.appCard)
                            .foregroundColor(.appAccent)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous).stroke(Color.appAccent, lineWidth: 1))
                    }
                    .disabled(viewModel.isLoading || viewModel.email.isEmpty || viewModel.password.isEmpty)
                    .padding(.horizontal, 32)
                    .padding(.top, -8)
                }
                
                if viewModel.mfaRequired {
                    Button("Cancel") {
                        Task { await viewModel.signOut() }
                    }
                    .font(.footnote)
                    .foregroundColor(.appSecondaryText)
                    .padding(.top, 8)
                }

                Spacer()
            }
        }
    }
}
