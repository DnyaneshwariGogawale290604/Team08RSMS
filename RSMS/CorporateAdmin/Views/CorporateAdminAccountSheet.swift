import SwiftUI

public struct CorporateAdminAccountSheet: View {
    @ObservedObject var sessionViewModel: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    public init(sessionViewModel: SessionViewModel) {
        self.sessionViewModel = sessionViewModel
    }

    public var body: some View {
        NavigationView {
            CorporateAdminAccountView(sessionViewModel: sessionViewModel)
                .navigationTitle("Account")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Close") { dismiss() }
                    }
                }
        }
    }
}

private struct CorporateAdminAccountView: View {
    @ObservedObject var sessionViewModel: SessionViewModel

    var body: some View {
        ZStack {
            Color.luxuryBackground.ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "person.crop.circle")
                    .font(.system(size: 72))
                    .foregroundColor(Color.luxurySecondaryText)

                Text("Corporate Admin")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(Color.luxuryPrimaryText)

                NavigationLink {
                    GatewaySetupView()
                } label: {
                    HStack {
                        Image(systemName: "creditcard.fill")
                            .foregroundColor(CatalogTheme.primary)
                        Text("Payment Gateway Setup")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(Color.luxuryPrimaryText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(Color.luxurySecondaryText)
                            .font(.system(size: 13))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .cornerRadius(12)
                    .padding(.horizontal, 24)
                }

                Button {
                    Task { await sessionViewModel.signOut() }
                } label: {
                    Text("Logout")
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .luxuryPrimaryButtonChrome(cornerRadius: 16)
                }
                .buttonStyle(LuxuryPressStyle())
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
