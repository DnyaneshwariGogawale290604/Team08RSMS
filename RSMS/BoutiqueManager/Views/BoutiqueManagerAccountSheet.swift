import SwiftUI

public struct BoutiqueManagerProfileButton: View {
    @ObservedObject var sessionViewModel: SessionViewModel
    @State private var showingAccountSheet = false

    public init(sessionViewModel: SessionViewModel) {
        self.sessionViewModel = sessionViewModel
    }

    public var body: some View {
        Button {
            showingAccountSheet = true
        } label: {
            AppProfileToolbarButton()
        }
        .sheet(isPresented: $showingAccountSheet) {
            BoutiqueManagerAccountSheet(sessionViewModel: sessionViewModel)
        }
    }
}

public struct BoutiqueManagerAccountSheet: View {
    @ObservedObject var sessionViewModel: SessionViewModel
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationView {
            ZStack {
                Color.luxuryBackground.ignoresSafeArea()

                VStack(spacing: 20) {
                    Spacer()

                    VStack(spacing: 14) {
                        Image(systemName: "person.crop.circle.badge.checkmark")
                            .font(.system(size: 68))
                            .foregroundStyle(Color.luxurySecondaryText)

                        Text("Boutique Manager")
                            .font(BrandFont.display(24, weight: .bold))
                            .foregroundStyle(Color.luxuryPrimaryText)

                        Text("Store overview, reports, and staff management.")
                            .font(BrandFont.body(14))
                            .foregroundStyle(Color.luxurySecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 28)

                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            NavigationLink(destination: StoreProfileView()) {
                                accountInfoCard(
                                    title: "Store Profile",
                                    subtitle: "View and edit details",
                                    icon: "storefront.fill"
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            accountInfoCard(
                                title: "Reports",
                                subtitle: "Sales and inventory",
                                icon: "chart.bar.doc.horizontal.fill"
                            )
                        }

                        LanguageSwitcherRow()

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
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 34, height: 34)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                    }
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
