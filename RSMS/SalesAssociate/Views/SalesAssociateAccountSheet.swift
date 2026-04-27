import SwiftUI

struct SalesAssociateProfileButton: View {
    @ObservedObject var sessionViewModel: SessionViewModel
    @State private var showingAccountSheet = false

    var body: some View {
        Button {
            showingAccountSheet = true
        } label: {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color.luxuryPrimaryText)
                .accessibilityLabel("Account")
        }
        .sheet(isPresented: $showingAccountSheet) {
            SalesAssociateAccountSheet(sessionViewModel: sessionViewModel)
        }
    }
}

struct SalesAssociateAccountSheet: View {
    @ObservedObject var sessionViewModel: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.luxuryBackground.ignoresSafeArea()

                VStack(spacing: 20) {
                    Spacer()

                    VStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 68))
                            .foregroundStyle(Color.luxurySecondaryText)

                        Text("Sales Associate")
                            .font(BrandFont.display(24, weight: .bold))
                            .foregroundStyle(Color.luxuryPrimaryText)

                        Text("Clienteling, appointments, orders, and billing in one place.")
                            .font(BrandFont.body(14))
                            .foregroundStyle(Color.luxurySecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 28)

                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            accountInfoCard(
                                title: "Client Book",
                                subtitle: "Profiles and preferences",
                                icon: "person.2.fill"
                            )
                            accountInfoCard(
                                title: "Checkout",
                                subtitle: "Orders and billing",
                                icon: "bag.fill"
                            )
                        }

                        Button {
                            Task { await sessionViewModel.signOut() }
                        } label: {
                            Text("Logout")
                                .font(BrandFont.body(15, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .luxuryPrimaryButtonChrome(cornerRadius: 16)
                        }
                        .buttonStyle(LuxuryPressStyle())
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(Color.luxuryPrimary)
                }
            }
        }
    }

    private func accountInfoCard(title: String, subtitle: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.luxuryPrimary)

            Text(title)
                .font(BrandFont.body(15, weight: .semibold))
                .foregroundStyle(Color.luxuryPrimaryText)

            Text(subtitle)
                .font(BrandFont.body(12))
                .foregroundStyle(Color.luxurySecondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}
