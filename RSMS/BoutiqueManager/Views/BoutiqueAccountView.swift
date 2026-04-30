import SwiftUI

struct BoutiqueProfileButton: View {
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @State private var showingAccountSheet = false

    var body: some View {
        Button {
            showingAccountSheet = true
        } label: {
            AppProfileToolbarButton()
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingAccountSheet) {
            BoutiqueAccountView()
                .environmentObject(sessionViewModel)
        }
    }
}

struct BoutiqueAccountView: View {
    @EnvironmentObject private var sessionViewModel: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.luxuryBackground.ignoresSafeArea()

                VStack(spacing: 20) {
                    Spacer()

                    VStack(spacing: 14) {
                        Image(systemName: "storefront.fill")
                            .font(.system(size: 68))
                            .foregroundStyle(Color.luxurySecondaryText)

                        Text("Boutique Manager")
                            .font(BrandFont.display(24, weight: .bold))
                            .foregroundStyle(Color.luxuryPrimaryText)

                        Text("Store operations, inventory visibility, and team coordination in one place.")
                            .font(BrandFont.body(14))
                            .foregroundStyle(Color.luxurySecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 28)

                    VStack(spacing: 14) {
                        NavigationLink {
                            StoreProfileView()
                        } label: {
                            accountInfoCard(
                                title: "Boutique Details",
                                subtitle: "Targets, location, and store configuration",
                                icon: "building.2.fill"
                            )
                        }
                        .buttonStyle(.plain)

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
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .foregroundStyle(Color.luxuryPrimaryText)
                }
            }
        }
    }

    private func accountInfoCard(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Color.luxuryPrimary)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(BrandFont.body(15, weight: .semibold))
                    .foregroundStyle(Color.luxuryPrimaryText)

                Text(subtitle)
                    .font(BrandFont.body(12))
                    .foregroundStyle(Color.luxurySecondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.luxurySecondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}
