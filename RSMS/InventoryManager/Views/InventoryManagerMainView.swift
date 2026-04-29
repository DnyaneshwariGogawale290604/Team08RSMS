import SwiftUI

public struct InventoryManagerMainView: View {
    @State private var selectedTab = 0
    @State private var prefilledSKUMagic: String? = nil
    @State private var categoryFilterMagic: String? = nil
    @State private var repairFilter: ItemsTabView.RepairFilter = .all
    
    public init() {}
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            DashboardTabView(selectedTab: $selectedTab, prefilledSKUMagic: $prefilledSKUMagic, categoryFilterMagic: $categoryFilterMagic, repairFilter: $repairFilter)
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
            
            ItemsTabView(categoryFilterMagic: $categoryFilterMagic, repairFilter: $repairFilter)
                .tabItem {
                    Image(systemName: "shippingbox.fill")
                    Text("Items")
                }
                .tag(2)
            
            RequestsTabView(selectedTab: $selectedTab, prefilledSKUMagic: $prefilledSKUMagic)
                .tabItem {
                    Image(systemName: "bell.badge.fill")
                    Text("Requests")
                }
                .tag(3)
        }
        .tint(.appAccent)
    }
}
