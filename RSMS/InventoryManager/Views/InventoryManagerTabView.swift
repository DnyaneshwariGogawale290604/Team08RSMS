import SwiftUI

public struct InventoryManagerTabView: View {
    @ObservedObject private var sessionViewModel: SessionViewModel

    public init(sessionViewModel: SessionViewModel) {
        self.sessionViewModel = sessionViewModel
    }

    public var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "squareshape.split.2x2")
                }

            NavigationView {
                RequestsTabView()
            }
            .tabItem {
                Label("Requests", systemImage: "tray.full")
            }

            NavigationView {
                TransfersTabView(selectedTab: .constant(1), prefilledSKUMagic: .constant(nil as String?))
            }
            .tabItem {
                Label("Workflows", systemImage: "arrow.left.arrow.right")
            }

            ItemsTabView(categoryFilterMagic: .constant(nil as String?))
                .tabItem {
                    Label("Items", systemImage: "shippingbox")
                }

            accountTab
                .tabItem {
                    Label("Account", systemImage: "person.crop.circle")
                }
        }
        .tint(.luxuryPrimary)
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
        NavigationView {
            ZStack {
                Color.luxuryBackground.ignoresSafeArea()

                VStack(spacing: 20) {
                    Spacer()

                    Image(systemName: "shippingbox")
                        .font(.system(size: 72))
                        .foregroundColor(.luxurySecondaryText)

                    Text("Inventory Manager")
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle("Account")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}
