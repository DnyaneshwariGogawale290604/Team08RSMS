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
                        Button { dismiss() } label: {
                            Image(systemName: "xmark")
                        }
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

                VStack(spacing: 14) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 72))
                        .foregroundColor(Color.luxurySecondaryText)

                    Text("Corporate Admin")
                        .font(BrandFont.display(24, weight: .bold))
                        .foregroundColor(Color.luxuryPrimaryText)

                    Text("Manage brand operations, store setup, and payment infrastructure.")
                        .font(BrandFont.body(14))
                        .foregroundColor(Color.luxurySecondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }

                VStack(spacing: 12) {
                    NavigationLink {
                        GatewaySetupView()
                    } label: {
                        accountActionRow(
                            title: "Payment Gateway Setup",
                            subtitle: "Manage all supported gateways",
                            icon: "creditcard.fill"
                        )
                    }

                    NavigationLink {
                        DiscountListView()
                    } label: {
                        accountActionRow(
                            title: "Discounts & Promotions",
                            subtitle: "Create coupons and marketing offers",
                            icon: "tag.fill"
                        )
                    }

                    NavigationLink {
                        GatewaySetupView(initialGateway: .razorpay)
                    } label: {
                        accountActionRow(
                            title: "Razorpay Setup",
                            subtitle: "Quick access to Razorpay keys and methods",
                            icon: "bolt.horizontal.circle.fill"
                        )
                    }
                }
                .padding(.horizontal, 24)

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
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func accountActionRow(title: String, subtitle: String, icon: String) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(CatalogTheme.surface)
                    .frame(width: 42, height: 42)

                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(CatalogTheme.primary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(BrandFont.body(15, weight: .semibold))
                    .foregroundColor(Color.luxuryPrimaryText)

                Text(subtitle)
                    .font(BrandFont.body(12))
                    .foregroundColor(Color.luxurySecondaryText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(Color.luxurySecondaryText)
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}
