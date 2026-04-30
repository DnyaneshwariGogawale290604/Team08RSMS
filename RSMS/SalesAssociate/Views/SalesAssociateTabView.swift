import SwiftUI

struct SalesAssociateTabView: View {
    @ObservedObject private var sessionViewModel: SessionViewModel
    @StateObject private var orderStore = SharedOrderStore()

    init(sessionViewModel: SessionViewModel) {
        self.sessionViewModel = sessionViewModel
    }

    var body: some View {
        TabView {
            SalesAssociateDashboardView(sessionViewModel: sessionViewModel)
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2")
                }

            SalesAssociateAppointmentsView(sessionViewModel: sessionViewModel)
                .tabItem {
                    Label("Appointments", systemImage: "calendar")
                }

            SalesAssociateOrdersView(sessionViewModel: sessionViewModel)
                .tabItem {
                    Label("Orders", systemImage: "cart")
                }

            SalesAssociateClientsView(sessionViewModel: sessionViewModel)
                .tabItem {
                    Label("Clients", systemImage: "person.2")
                }
        }
        .tint(.luxurySelection)
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
        let selectedColor = UIColor(Color.luxurySelection)

        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().unselectedItemTintColor = normalColor
    }
}
