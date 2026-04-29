import SwiftUI

public struct InventoryManagerTabView: View {
    @ObservedObject private var sessionViewModel: SessionViewModel
    @State private var showingAccountSheet = false
    @State private var selectedTab: Int = 0
    @State private var prefilledSKUMagic: String? = nil
    @State private var categoryFilterMagic: String? = nil
    @State private var repairFilter: ItemsTabView.RepairFilter = .all

    public init(sessionViewModel: SessionViewModel) {
        self.sessionViewModel = sessionViewModel
    }

    public var body: some View {
        TabView(selection: $selectedTab) {
            DashboardTabView(
                selectedTab: $selectedTab,
                prefilledSKUMagic: $prefilledSKUMagic,
                categoryFilterMagic: $categoryFilterMagic,
                repairFilter: $repairFilter,
                onAccountTapped: { showingAccountSheet = true }
            )
            .tabItem {
                Label("Dashboard", systemImage: "square.grid.2x2.fill")
            }
            .tag(0)

            NavigationView {
                RequestsTabView(selectedTab: $selectedTab, prefilledSKUMagic: $prefilledSKUMagic)
            }
            .tabItem {
                Label("Requests", systemImage: "tray.full")
            }
            .tag(1)

            NavigationView {
                TransfersTabView(selectedTab: $selectedTab, prefilledSKUMagic: $prefilledSKUMagic)
            }
            .tabItem {
                Label("Workflows", systemImage: "arrow.left.arrow.right")
            }
            .tag(2)

            ItemsTabView(categoryFilterMagic: $categoryFilterMagic, repairFilter: $repairFilter)
                .tabItem {
                    Label("Items", systemImage: "shippingbox")
                }
                .tag(3)

            ReportsTabView()
                .tabItem {
                    Label("Reports", systemImage: "chart.bar.doc.horizontal")
                }
                .tag(4)
        }
        .accentColor(Color(hex: "#6E5155"))
        .onAppear {
            configureTabBarAppearance()
        }
        .sheet(isPresented: $showingAccountSheet) {
            accountTab
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
