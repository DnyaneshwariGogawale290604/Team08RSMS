import SwiftUI

// MARK: - Inventory Management View (Segmented: Stock Levels + Alerts)

public struct InventoryManagementView: View {
    @EnvironmentObject var inventoryVM: InventoryViewModel
    @State private var selectedTab = 0
    @State private var showOrderStock = false
    @State private var preselectedProductId: UUID?
    @State private var searchText = ""
    
    public init() {}
    
    private var filteredInventory: [InventoryProduct] {
        if searchText.isEmpty { return inventoryVM.inventoryList }
        return inventoryVM.inventoryList.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var nonOrderedAlerts: [StockAlert] {
        inventoryVM.activeAlerts.filter { alert in
            (searchText.isEmpty || alert.message.localizedCaseInsensitiveContains(searchText)) &&
            alert.requestStatus == nil
        }
    }
    
    private var alertCount: Int { inventoryVM.activeAlerts.count }
    
    private var lowStockCount: Int { nonOrderedAlerts.count }
    
    public var body: some View {
        NavigationView {
            ZStack {
                BoutiqueTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Segmented picker — Stock Levels | Low Stock | Orders
                    InventorySegmentedControl(
                        selected: $selectedTab
                    )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 8)
                    
                    // Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(BoutiqueTheme.primary)
                        TextField("Search inventory...", text: $searchText)
                            .foregroundColor(BoutiqueTheme.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(BoutiqueTheme.surface)
                    .cornerRadius(20)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
                    

                    
                    if inventoryVM.isLoading {
                        Spacer()
                        LoadingView(message: "Loading inventory...")
                        Spacer()
                    } else if let error = inventoryVM.errorMessage {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.largeTitle).foregroundColor(BoutiqueTheme.error)
                            Text(error)
                                .foregroundColor(.appSecondaryText)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                        }.padding(40)
                        Spacer()
                    } else {
                        if selectedTab == 0 {
                            StockLevelsTab(inventoryList: filteredInventory) { product in
                                inventoryVM.toggleProductAvailability(product: product)
                            }
                        } else {
                            LowStockTab(
                                alerts: nonOrderedAlerts,
                                inventoryList: inventoryVM.inventoryList,
                                orderedProductIds: inventoryVM.orderedProductIds,
                                onDismiss: { id in inventoryVM.resolveAlert(id: id) },
                                onOrder: { productId, orderQty in
                                    inventoryVM.orderStock(productId: productId, quantity: orderQty)
                                }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Inventory")
            .toolbarColorScheme(.light, for: .navigationBar)
            
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        preselectedProductId = nil
                        showOrderStock = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(BoutiqueTheme.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showOrderStock) {
                OrderStockView(preselectedInventoryId: preselectedProductId).environmentObject(inventoryVM)
            }
            .onAppear {
                inventoryVM.fetchInventoryAndAlerts()
            }
        }
    }
}

// MARK: - Segmented Control

struct InventorySegmentedControl: View {
    @Binding var selected: Int
    
    private var tabs: [(String, String)] {
        [
            ("Stock Levels", "Stock Levels"),
            ("Low Stock", "Low Stock")
        ]
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selected = index } }) {
                    Text(tab.0)
                        .font(.system(size: 13, weight: selected == index ? .semibold : .regular))
                        .foregroundColor(selected == index ? .white : BoutiqueTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selected == index
                                ? BoutiqueTheme.primary
                                : Color.clear
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(BoutiqueTheme.card)
        .clipShape(Capsule())
    }
}

// MARK: - Stock Levels Tab

struct StockLevelsTab: View {
    let inventoryList: [InventoryProduct]
    let onToggle: (InventoryProduct) -> Void
    
    var body: some View {
        if inventoryList.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "cube.box")
                    .font(.system(size: 48)).foregroundColor(BoutiqueTheme.border)
                Text("No inventory data").foregroundColor(BoutiqueTheme.textSecondary)
            }
            Spacer()
        } else {
            List {
                ForEach(inventoryList) { product in
                    StockLevelRow(product: product)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
        }
    }
}

struct StockLevelRow: View {
    let product: InventoryProduct
    
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Category icon
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(BoutiqueTheme.surface)
                        .frame(width: 44, height: 44)
                    Image(systemName: iconFor(product.category))
                        .foregroundColor(BoutiqueTheme.primary)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.name)
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(CatalogTheme.primaryText)
                }
                
                Spacer()
                
                // Stock count
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(product.stockQuantity)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(product.isLowStock ? BoutiqueTheme.error : BoutiqueTheme.textPrimary)
                    Text("in stock")
                        .font(.caption2)
                        .foregroundColor(BoutiqueTheme.textSecondary)
                }
                
                // Removed Sort/transfer icon
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            
        }
        .boutiqueCardChrome()
    }
    
    private func iconFor(_ category: String) -> String {
        switch category.lowercased() {
        case "jewellery", "jewelry", "necklace", "ring", "earring": return "sparkles"
        case "watches", "watch": return "clock"
        case "bags", "handbags", "luggage": return "bag"
        case "clothing", "apparel", "gown", "dress": return "tshirt"
        case "shoes", "footwear": return "shoeprints.fill"
        case "accessories": return "sparkle"
        case "fragrance", "perfume": return "drop"
        default: return "tag"
        }
    }
}

// MARK: - Low Stock Tab

struct LowStockTab: View {
    let alerts: [StockAlert]
    let inventoryList: [InventoryProduct]
    let orderedProductIds: Set<UUID>
    let onDismiss: (UUID) -> Void
    let onOrder: (UUID, Int) -> Void
    
    var body: some View {
        if alerts.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 48)).foregroundColor(BoutiqueTheme.primary)
                Text("All stock levels are healthy").font(.headline).foregroundColor(BoutiqueTheme.textPrimary)
                Text("No replenishment needed at this time")
                    .font(.subheadline).foregroundColor(BoutiqueTheme.textSecondary)
            }
            Spacer()
        } else {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(alerts) { alert in
                        let product = inventoryList.first { $0.productId == alert.productId }
                        AlertCard(
                            alert: alert,
                            currentStock: product?.stockQuantity ?? 0,
                            threshold: product?.baselineQuantity ?? 15,
                            isOrdered: orderedProductIds.contains(alert.productId),
                            hideOrderButton: false,
                            onResolve: { onDismiss(alert.id) },
                            onOrder: { qty in onOrder(alert.productId, qty) }
                        )
                    }
                }
                .padding(16)
            }
        }
    }
}


struct AlertCard: View {
    let alert: StockAlert
    let currentStock: Int
    let threshold: Int
    let isOrdered: Bool
    let hideOrderButton: Bool
    let onResolve: () -> Void
    let onOrder: (Int) -> Void
    
    @State private var showDismissAlert = false
    @State private var showOrderAlert = false
    @State private var orderQuantity = ""
    
    private var isCritical: Bool { alert.priority == .critical }
    
    private var isRejected: Bool {
        alert.requestStatus?.lowercased() == "rejected" || alert.rejectionReason != nil
    }
    
    private var statusText: String {
        if isRejected { return "Rejected" }
        if alert.requestStatus?.lowercased() == "approved" { return "Approved" }
        if isOrdered || alert.requestStatus?.lowercased() == "pending" { return "Order placed" }
        return "Just now"
    }
    
    private var statusColor: Color {
        if isRejected { return BoutiqueTheme.error }
        if isOrdered || alert.requestStatus?.lowercased() == "pending" || alert.requestStatus?.lowercased() == "approved" { return BoutiqueTheme.primary }
        return BoutiqueTheme.textSecondary
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: Product name + Status
            HStack(alignment: .top, spacing: 12) {
                Text(alert.message.components(separatedBy: " is low").first ?? alert.message)
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(CatalogTheme.primaryText)
                    .lineLimit(2)
                
                Spacer()
                
                Text(statusText)
                    .font(.caption2)
                    .fontWeight(isOrdered || isRejected || alert.requestStatus != nil ? .bold : .regular)
                    .foregroundColor(statusColor)
                    .fixedSize(horizontal: true, vertical: false)
            }
                
            if isRejected {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill").font(.caption)
                        Text("Order Rejected")
                            .font(.caption).fontWeight(.bold)
                    }
                    .foregroundColor(BoutiqueTheme.error)
                    
                    if let reason = alert.rejectionReason, !reason.isEmpty {
                        Text(reason)
                            .font(.caption2)
                            .foregroundColor(BoutiqueTheme.textSecondary)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(BoutiqueTheme.error.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Stats row
            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Stock")
                        .font(.caption2)
                        .foregroundColor(BoutiqueTheme.textSecondary)
                    Text("\(currentStock)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(BoutiqueTheme.textPrimary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Threshold")
                        .font(.caption2)
                        .foregroundColor(BoutiqueTheme.textSecondary)
                    Text("\(threshold)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(BoutiqueTheme.textPrimary)
                }
                Spacer()
                
                // Action buttons
                VStack(spacing: 8) {
                    if !hideOrderButton {
                        Button(action: { showDismissAlert = true }) {
                            Text("Dismiss")
                                .font(.system(size: 13, weight: .medium))
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundColor(isRejected ? BoutiqueTheme.textSecondary : BoutiqueTheme.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isRejected ? BoutiqueTheme.textSecondary.opacity(0.12) : BoutiqueTheme.surface)
                                .cornerRadius(10)
                        }
                        .alert("Dismiss Alert?", isPresented: $showDismissAlert) {
                            Button("Cancel", role: .cancel) {}
                            Button("Dismiss", role: .destructive) { onResolve() }
                        } message: {
                            Text("Are you sure you want to dismiss this low stock alert?")
                        }
                    } else {
                        Button(action: onResolve) {
                            Text("Received")
                                .font(.system(size: 13, weight: .medium))
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundColor(BoutiqueTheme.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(BoutiqueTheme.surface)
                                .cornerRadius(10)
                        }
                    }
                    
                    if !hideOrderButton {
                        Button(action: { showOrderAlert = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: isOrdered ? "box.truck.fill" : "box.truck")
                                    .font(.system(size: 11))
                                Text(isOrdered || isRejected ? "Re-Order" : "Order")
                                    .font(.system(size: 12, weight: .medium))
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .foregroundColor(isOrdered ? BoutiqueTheme.textSecondary : BoutiqueTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isOrdered ? BoutiqueTheme.border.opacity(0.3) : BoutiqueTheme.beige)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isOrdered ? BoutiqueTheme.border : BoutiqueTheme.textPrimary.opacity(0.2), lineWidth: 1)
                            )
                        }
                        .disabled(isOrdered && !isRejected)
                        .alert("Order Quantity", isPresented: $showOrderAlert) {
                            TextField("Enter quantity", text: $orderQuantity)
#if canImport(UIKit)
                                .keyboardType(.numberPad)
#endif
                            Button("Cancel", role: .cancel) { orderQuantity = "" }
                            Button("Place Order") {
                                if let qty = Int(orderQuantity), qty > 0 {
                                    onOrder(qty)
                                }
                                orderQuantity = ""
                            }
                        } message: {
                            Text("Enter the quantity you wish to order.")
                        }
                    }
                }
            }
        }
        .padding(16)
        .boutiqueCardChrome()
    }
}

// MARK: - Assortment Tab (Toggle product availability)

struct AssortmentTab: View {
    let inventoryList: [InventoryProduct]
    let onToggle: (InventoryProduct) -> Void
    
    var body: some View {
        List {
            ForEach(inventoryList) { product in
                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(product.name)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(product.enabledInStore ? BoutiqueTheme.textPrimary : BoutiqueTheme.textSecondary)
                        Text(product.category)
                            .font(.caption)
                            .foregroundColor(BoutiqueTheme.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { product.enabledInStore },
                        set: { _ in onToggle(product) }
                    ))
                    .labelsHidden()
                    .tint(BoutiqueTheme.primary)
                }
                .padding(.vertical, 6)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
