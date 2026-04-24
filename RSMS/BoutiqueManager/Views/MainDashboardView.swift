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
                .environmentObject(sessionViewModel)
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
    }
}
