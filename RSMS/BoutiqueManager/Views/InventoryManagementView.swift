import SwiftUI

// MARK: - Inventory Management View (Segmented: Stock Levels + Alerts)

public struct InventoryManagementView: View {
    @EnvironmentObject var inventoryVM: InventoryViewModel
    @State private var selectedTab = 0
    @State private var showOrderStock = false
    @State private var preselectedProductId: UUID?
    
    public init() {}
    
    private var nonOrderedAlerts: [StockAlert] {
        inventoryVM.activeAlerts.filter { alert in
            !(inventoryVM.orderedProductIds.contains(alert.productId)
              || alert.requestStatus?.lowercased() == "pending"
              || alert.requestStatus?.lowercased() == "approved")
        }
    }
    
    private var orderedAlerts: [StockAlert] {
        inventoryVM.activeAlerts.filter { alert in
            inventoryVM.orderedProductIds.contains(alert.productId)
            || alert.requestStatus?.lowercased() == "pending"
            || alert.requestStatus?.lowercased() == "approved"
        }
    }
    
    private var alertCount: Int { inventoryVM.activeAlerts.count }
    
    private var lowStockCount: Int { nonOrderedAlerts.count }
    private var orderCount: Int { orderedAlerts.count }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Segmented picker — Stock Levels | Low Stock | Orders
                    InventorySegmentedControl(
                        selected: $selectedTab,
                        lowStockCount: lowStockCount,
                        orderCount: orderCount
                    )
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 4)
                    
                    Divider().background(Color.appBorder)
                    
                    if inventoryVM.isLoading {
                        Spacer()
                        LoadingView(message: "Loading inventory...")
                        Spacer()
                    } else if let error = inventoryVM.errorMessage {
                        Spacer()
                        VStack(spacing: 10) {
                            Image(systemName: "exclamationmark.circle")
                                .font(.largeTitle).foregroundColor(Theme.error)
                            Text(error)
                                .foregroundColor(.appSecondaryText)
                                .font(.subheadline)
                                .multilineTextAlignment(.center)
                        }.padding(40)
                        Spacer()
                    } else {
                        if selectedTab == 0 {
                            StockLevelsTab(inventoryList: inventoryVM.inventoryList) { product in
                                inventoryVM.toggleProductAvailability(product: product)
                            }
                        } else if selectedTab == 1 {
                            LowStockTab(
                                alerts: nonOrderedAlerts,
                                inventoryList: inventoryVM.inventoryList,
                                orderedProductIds: inventoryVM.orderedProductIds,
                                onDismiss: { id in inventoryVM.resolveAlert(id: id) },
                                onOrder: { productId in
                                    if let product = inventoryVM.inventoryList.first(where: { $0.productId == productId }) {
                                        let orderQty = max(1, product.baselineQuantity - product.stockQuantity)
                                        inventoryVM.orderStock(productId: productId, quantity: orderQty)
                                    }
                                }
                            )
                        } else {
                            OrdersTab(
                                alerts: orderedAlerts,
                                inventoryList: inventoryVM.inventoryList,
                                orderedProductIds: inventoryVM.orderedProductIds,
                                onDismiss: { id in inventoryVM.resolveAlert(id: id) }
                            )
                        }
                    }
                }
            }
            .navigationTitle("Inventory")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        preselectedProductId = nil
                        showOrderStock = true
                    }) {
                        Image(systemName: "plus")
                            .foregroundColor(Theme.textPrimary)
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
    let lowStockCount: Int
    let orderCount: Int
    
    private var tabs: [(String, String)] {
        [
            ("Stock Levels", "Stock Levels"),
            (lowStockCount > 0 ? "Low Stock (\(lowStockCount))" : "Low Stock", "Low Stock"),
            (orderCount > 0 ? "Orders (\(orderCount))" : "Orders", "Orders")
        ]
    }
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { selected = index } }) {
                    Text(tab.0)
                        .font(.system(size: 13, weight: selected == index ? .semibold : .regular))
                        .foregroundColor(selected == index ? Theme.textPrimary : Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selected == index
                                ? Color.appBackground
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        .padding(4)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius, style: .continuous))
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
                    .font(.system(size: 48)).foregroundColor(Theme.border)
                Text("No inventory data").foregroundColor(Theme.textSecondary)
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
                        .fill(Theme.beige)
                        .frame(width: 44, height: 44)
                    Image(systemName: iconFor(product.category))
                        .foregroundColor(Theme.textSecondary)
                        .font(.system(size: 18))
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(Theme.textPrimary)
                }
                
                Spacer()
                
                // Stock count
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(product.stockQuantity)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(product.isLowStock ? Theme.error : Theme.textPrimary)
                    Text("in stock")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                }
                
                // Removed Sort/transfer icon
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 14)
            
        }
        .appCardChrome()
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
    let onOrder: (UUID) -> Void
    
    var body: some View {
        if alerts.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 48)).foregroundColor(Theme.primary)
                Text("All stock levels are healthy").font(.headline).foregroundColor(Theme.textPrimary)
                Text("No replenishment needed at this time")
                    .font(.subheadline).foregroundColor(Theme.textSecondary)
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
                            onOrder: { onOrder(alert.productId) }
                        )
                    }
                }
                .padding(16)
            }
        }
    }
}

// MARK: - Orders Tab

struct OrdersTab: View {
    let alerts: [StockAlert]
    let inventoryList: [InventoryProduct]
    let orderedProductIds: Set<UUID>
    let onDismiss: (UUID) -> Void
    
    var body: some View {
        if alerts.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "box.truck")
                    .font(.system(size: 48)).foregroundColor(Theme.textSecondary)
                Text("No active orders").font(.headline).foregroundColor(Theme.textPrimary)
                Text("Your placed orders will appear here")
                    .font(.subheadline).foregroundColor(Theme.textSecondary)
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
                            hideOrderButton: true,
                            onResolve: { onDismiss(alert.id) },
                            onOrder: { }
                        )
                    }
                }
                .padding(16)
            }
        }
    }
}

// MARK: - Alert Section Header

struct AlertSectionHeader: View {
    let title: String
    let subtitle: String
    let iconName: String
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }
}

// MARK: - Alerts Tab (kept for compatibility)

struct AlertsTab: View {
    let alerts: [StockAlert]
    let inventoryList: [InventoryProduct]
    let orderedProductIds: Set<UUID>
    let onResolve: (UUID) -> Void
    let onOrder: (UUID) -> Void
    
    var body: some View {
        if alerts.isEmpty {
            Spacer()
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 48)).foregroundColor(Theme.primary)
                Text("No active alerts").font(.headline).foregroundColor(Theme.textPrimary)
                Text("All stock levels are healthy")
                    .font(.subheadline).foregroundColor(Theme.textSecondary)
            }
            Spacer()
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(alerts) { alert in
                        let product = inventoryList.first { $0.productId == alert.productId }
                        AlertCard(
                            alert: alert,
                            currentStock: product?.stockQuantity ?? 0,
                            threshold: product?.baselineQuantity ?? 15,
                            isOrdered: orderedProductIds.contains(alert.productId),
                            hideOrderButton: false,
                            onResolve: { onResolve(alert.id) },
                            onOrder: { onOrder(alert.productId) }
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
    let onOrder: () -> Void
    
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
        if isRejected { return Theme.error }
        if isOrdered || alert.requestStatus?.lowercased() == "pending" || alert.requestStatus?.lowercased() == "approved" { return Theme.primary }
        return Theme.textSecondary
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row
            HStack(alignment: .top) {
                Spacer()
                Text(statusText)
                    .font(.caption2)
                    .fontWeight(isOrdered || isRejected || alert.requestStatus != nil ? .bold : .regular)
                    .foregroundColor(statusColor)
            }
            
            // Product name
            Text(alert.message.components(separatedBy: " is low").first ?? alert.message)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)
                .lineLimit(2)
                
            if isRejected {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill").font(.caption)
                        Text("Order Rejected")
                            .font(.caption).fontWeight(.bold)
                    }
                    .foregroundColor(Theme.error)
                    
                    if let reason = alert.rejectionReason, !reason.isEmpty {
                        Text(reason)
                            .font(.caption2)
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.error.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Stats row
            HStack(alignment: .top, spacing: 32) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Stock")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text("\(currentStock)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Threshold")
                        .font(.caption2)
                        .foregroundColor(Theme.textSecondary)
                    Text("\(threshold)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.textPrimary)
                }
                Spacer()
                
                // Action buttons
                VStack(spacing: 8) {
                    if !hideOrderButton {
                        Button(action: onResolve) {
                            Text("Dismiss")
                                .font(.system(size: 13, weight: .medium))
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundColor(isRejected ? Theme.textSecondary : Theme.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isRejected ? Theme.textSecondary.opacity(0.12) : Theme.surface)
                                .cornerRadius(10)
                        }
                    } else {
                        Button(action: onResolve) {
                            Text("Received")
                                .font(.system(size: 13, weight: .medium))
                                .fixedSize(horizontal: true, vertical: false)
                                .foregroundColor(Theme.primary)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Theme.surface)
                                .cornerRadius(10)
                        }
                    }
                    
                    if !hideOrderButton {
                        Button(action: onOrder) {
                            HStack(spacing: 4) {
                                Image(systemName: isOrdered ? "box.truck.fill" : "box.truck")
                                    .font(.system(size: 11))
                                Text(isOrdered ? "Re-Order" : "Order")
                                    .font(.system(size: 12, weight: .medium))
                                    .fixedSize(horizontal: true, vertical: false)
                            }
                            .foregroundColor(isOrdered ? Theme.textSecondary : Theme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(isOrdered ? Theme.border.opacity(0.3) : Theme.beige)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isOrdered ? Theme.border : Theme.textPrimary.opacity(0.2), lineWidth: 1)
                            )
                        }
                    }
                }
            }
        }
        .padding(16)
        .appCardChrome()
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
                            .foregroundColor(product.enabledInStore ? Theme.textPrimary : Theme.textSecondary)
                        Text(product.category)
                            .font(.caption)
                            .foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { product.enabledInStore },
                        set: { _ in onToggle(product) }
                    ))
                    .labelsHidden()
                    .tint(Theme.primary)
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
