import SwiftUI

public struct InventoryManagerMainView: View {
    @State private var selectedTab = 0
    @State private var prefilledSKUMagic: String? = nil
    @State private var categoryFilterMagic: String? = nil
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            DashboardTabView(selectedTab: $selectedTab, prefilledSKUMagic: $prefilledSKUMagic, categoryFilterMagic: $categoryFilterMagic)
                .tabItem {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("Dashboard")
                }
                .tag(0)
            
            NavigationView {
                TransfersTabView(selectedTab: $selectedTab, prefilledSKUMagic: $prefilledSKUMagic)
            }
                .tabItem {
                    Image(systemName: "arrow.left.arrow.right")
                    Text("Workflows")
                }
                .tag(1)
            
            ItemsTabView(categoryFilterMagic: $categoryFilterMagic)
                .tabItem {
                    Image(systemName: "shippingbox.fill")
                    Text("Items")
                }
                .tag(2)
        }
        .tint(.appAccent)
    }
}
