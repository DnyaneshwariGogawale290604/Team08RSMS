import SwiftUI

struct CorporateAdminTabView: View {
    @ObservedObject private var sessionViewModel: SessionViewModel

    init(sessionViewModel: SessionViewModel) {
        self.sessionViewModel = sessionViewModel
    }

    var body: some View {
        TabView {
            AdminDashboardView(sessionViewModel: sessionViewModel)
                .tabItem {
                    Label("Dashboard", systemImage: "square.grid.2x2")
                }

            AdminManagementView(sessionViewModel: sessionViewModel)
                .tabItem {
                    Label("Staff", systemImage: "person.3.fill")
                }

            StoreListView(sessionViewModel: sessionViewModel)
                .tabItem {
                    Label("Stores", systemImage: "storefront.fill")
                }

            ProductListView(sessionViewModel: sessionViewModel)
                .tabItem {
                    Label("Catalog", systemImage: "tag.fill")
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

struct CorporateAdminTabView_Previews: PreviewProvider {
    static var previews: some View {
        CorporateAdminTabView(sessionViewModel: SessionViewModel())
    }
}
