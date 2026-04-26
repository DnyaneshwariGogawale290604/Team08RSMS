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
        .tint(.brandAccent)
    }

    private var accountTab: some View {
        NavigationView {
            ZStack {
                Color.brandOffWhite.ignoresSafeArea()

                VStack(spacing: 20) {
                    Spacer()

                    Image(systemName: "shippingbox")
                        .font(.system(size: 72))
                        .foregroundColor(.appSecondaryText)

                    Text("Inventory Manager")
                        .font(.title3.weight(.semibold))
                        .foregroundColor(.appPrimaryText)

                    Button {
                        Task { await sessionViewModel.signOut() }
                    } label: {
                        Text("Logout")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .appPrimaryButtonChrome()
                    }
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
