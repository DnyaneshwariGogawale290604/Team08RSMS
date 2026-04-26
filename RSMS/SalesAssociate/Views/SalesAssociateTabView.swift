import SwiftUI

struct SalesAssociateTabView: View {
    @ObservedObject private var sessionViewModel: SessionViewModel
    @StateObject private var orderStore = SharedOrderStore()

    init(sessionViewModel: SessionViewModel) {
        self.sessionViewModel = sessionViewModel
    }

    var body: some View {
        TabView {
            SalesAssociateDashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar")
                }

            SalesAssociateAppointmentsView()
                .tabItem {
                    Label("Appointments", systemImage: "calendar.badge.clock")
                }

            SalesAssociateOrdersView()
                .tabItem {
                    Label("Orders", systemImage: "shippingbox")
                }

            SalesAssociateClientsView()
                .tabItem {
                    Label("Clients", systemImage: "person.2")
                }

            accountTab
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle")
                }
        }
        .tint(.luxuryPrimary)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color.white, for: .tabBar)
        .environmentObject(orderStore)
        .onAppear {
            configureTabBarAppearance()
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.white

        let normalColor = UIColor(Color.luxuryMutedText)
        let selectedColor = UIColor(Color.luxuryPrimary)

        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().unselectedItemTintColor = normalColor
    }

    private var accountTab: some View {
        NavigationStack {
            ZStack {
                Color.luxuryBackground.ignoresSafeArea()

                VStack(spacing: 18) {
                    Spacer()

                    Image(systemName: "person.crop.circle.badge.checkmark")
                        .font(.system(size: 72))
                        .foregroundStyle(Color.luxurySecondaryText)

                    Text("Sales Associate")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundStyle(Color.luxuryPrimaryText)

                    Button {
                        Task { await sessionViewModel.signOut() }
                    } label: {
                        Text("Logout")
                            .font(BrandFont.body(15, weight: .semibold))
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                            .luxuryPrimaryButtonChrome(cornerRadius: 16)
                    }
                    .buttonStyle(LuxuryPressStyle())
                    .padding(.horizontal, 24)

                    Spacer()
                }
            }
            .navigationTitle("Account")
        }
    }
}
