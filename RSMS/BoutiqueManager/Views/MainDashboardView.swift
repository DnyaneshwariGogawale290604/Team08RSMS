import SwiftUI

public struct MainDashboardView: View {
    @ObservedObject private var sessionViewModel: SessionViewModel
    
    @StateObject private var dashboardVM = BoutiqueDashboardViewModel()
    @StateObject private var staffVM = StaffViewModel()
    @StateObject private var inventoryVM = InventoryViewModel()
    
    public init(sessionViewModel: SessionViewModel) {
        self.sessionViewModel = sessionViewModel
    }
    
    public var body: some View {
        TabView {
            HomeTabView()
                .environmentObject(dashboardVM)
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2")
                }
            
            CatalogView()
                .tabItem {
                    Label("Catalog", systemImage: "tag")
                }
            
            InventoryManagementView()
                .environmentObject(inventoryVM)
                .tabItem {
                    Label("Inventory", systemImage: "cube.box")
                }
            
            StaffManagementView()
                .environmentObject(staffVM)
                .tabItem {
                    Label("Staff", systemImage: "person.3")
                }

            accountTab
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle")
                }
        }
        .tint(CatalogTheme.primary)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(Color.white, for: .tabBar)
        .onAppear {
            configureTabBarAppearance()
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.white

        let normalColor = UIColor(CatalogTheme.mutedText)
        let selectedColor = UIColor(CatalogTheme.primary)

        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().unselectedItemTintColor = normalColor
    }

    private var accountTab: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "building.2.crop.circle")
                    .font(.system(size: 72))
                    .foregroundColor(.luxurySecondaryText)

                Text("Boutique Manager")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundColor(.luxuryPrimaryText)

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
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.luxuryBackground.ignoresSafeArea())
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
