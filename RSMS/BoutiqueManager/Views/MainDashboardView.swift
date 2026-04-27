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
            
            ShipmentTrackingView()
                .tabItem {
                    Label("Shipments", systemImage: "cart")
                }
            
            StaffManagementView()
                .environmentObject(staffVM)
                .tabItem {
                    Label("Staff", systemImage: "person.3")
                }
        }
        .tint(BoutiqueTheme.primary)
        .preferredColorScheme(.light)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(BoutiqueTheme.card, for: .tabBar)
        .onAppear {
            configureTabBarAppearance()
            configureNavigationBarAppearance()
        }
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.white

        let normalColor = UIColor(BoutiqueTheme.mutedText)
        let selectedColor = UIColor(BoutiqueTheme.primary)

        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = [.foregroundColor: normalColor]
        appearance.stackedLayoutAppearance.selected.iconColor = selectedColor
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = [.foregroundColor: selectedColor]

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        UITabBar.appearance().unselectedItemTintColor = normalColor
    }

    private func configureNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(BoutiqueTheme.background)
        appearance.shadowColor = .clear
        
        let titleColor = UIColor(BoutiqueTheme.primaryText)
        
        // Apply Bold fonts to Navigation Titles (Sans-Serif for consistency)
        let largeTitleFont = UIFont.systemFont(ofSize: 34, weight: .bold)
        let titleFont = UIFont.systemFont(ofSize: 17, weight: .bold)

        appearance.titleTextAttributes = [
            .foregroundColor: titleColor,
            .font: titleFont
        ]
        appearance.largeTitleTextAttributes = [
            .foregroundColor: titleColor,
            .font: largeTitleFont
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        
        // Fix for iOS 15+ navigation bar switching
        let proxy = UINavigationBar.appearance()
        proxy.standardAppearance = appearance
        proxy.compactAppearance = appearance
        proxy.scrollEdgeAppearance = appearance
    }
}
