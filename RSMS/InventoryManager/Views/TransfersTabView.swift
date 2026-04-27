import SwiftUI

public struct TransfersTabView: View {
    @StateObject private var viewModel = TransfersViewModel()
    @Binding var selectedTab: Int
    @Binding var prefilledSKUMagic: String?
    
    @State private var selectedSection: Int = 0 // 0: Purchase Orders, 1: Pick Lists, 2: Shipments Out
    @State private var showingCreatePO = false
    
    public init(selectedTab: Binding<Int>, prefilledSKUMagic: Binding<String?>) {
        self._selectedTab = selectedTab
        self._prefilledSKUMagic = prefilledSKUMagic
    }
    
    public var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Pill Picker
                Picker("Section", selection: $selectedSection) {
                    Text("Purchase Orders").tag(0)
                    Text("Pick Lists").tag(1)
                    Text("Shipments Out").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding()
                
                if selectedSection == 0 {
                    purchaseOrdersSection()
                } else if selectedSection == 1 {
                    pickListsSection()
                } else {
                    shipmentsOutSection()
                }
            }
            
            // FAB for new orders
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: {
                        showingCreatePO = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                            .padding(20)
                            .background(Color.appAccent)
                            .clipShape(Circle())
                            .shadow(radius: 5)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .navigationTitle("Workflows")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if prefilledSKUMagic != nil {
                selectedSection = 0
                showingCreatePO = true
            }
        }
        .task {
            await viewModel.loadData()
        }
        .refreshable {
            await viewModel.loadData()
        }
        .sheet(isPresented: $showingCreatePO) {
            CreatePOView(prefilledSKU: $prefilledSKUMagic)
        }
    }
    
    // MARK: - Sections
    
    @ViewBuilder
    private func purchaseOrdersSection() -> some View {
        let pos = viewModel.vendorOrders.map { Transfer(fromVendorOrder: $0) }
        List {
            ForEach(pos) { transfer in
                NavigationLink(destination: TransferDetailView(transfer: transfer)) {
                    transferRow(for: transfer)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
            }
        }
        .listStyle(.plain)
    }
    
    @ViewBuilder
    private func pickListsSection() -> some View {
        // IM-15: Show pending/approved demands that need picking
        let approvedPicks = viewModel.pickLists.map { Transfer(fromProductRequest: $0) }
        if approvedPicks.isEmpty {
            Spacer()
            Text("No approved pick lists right now.")
                .foregroundColor(.appSecondaryText)
            Spacer()
        } else {
            List {
                ForEach(approvedPicks) { demand in
                    NavigationLink(destination: PickListScanningView(demand: demand)) {
                        transferRow(for: demand)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
                }
            }
            .listStyle(.plain)
        }
    }
    
    @ViewBuilder
    private func shipmentsOutSection() -> some View {
        let activeShipments = viewModel.shipmentsOut.map { Transfer(fromShipment: $0) }
        List {
            ForEach(activeShipments) { transfer in
                NavigationLink(destination: TransferDetailView(transfer: transfer)) {
                    transferRow(for: transfer)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .padding(.vertical, 6)
                .padding(.horizontal, 16)
            }
        }
        .listStyle(.plain)
    }
    
    @ViewBuilder
    private func transferRow(for transfer: Transfer) -> some View {
        let totalQuantity = transfer.items.reduce(0) { $0 + $1.quantity }
        let itemNames = transfer.items.map { $0.productName }.joined(separator: ", ")
        let displayNames = itemNames.isEmpty ? "Unknown Product" : itemNames
        
        ReusableCardView {
            VStack(alignment: .leading, spacing: 12) {
                // Header: Order ID & Status
                HStack {
                    Text(transfer.orderId)
                        .font(.headline)
                        .foregroundColor(.appPrimaryText)
                    Spacer()
                    Text(transfer.status.rawValue)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(statusColor(transfer.status).opacity(0.15))
                        .foregroundColor(statusColor(transfer.status))
                        .clipShape(Capsule())
                }
                
                // Content: Type, Products, Quantity
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: transfer.type == .boutique ? "building.2.crop.circle" : "truck.box")
                                .foregroundColor(.appSecondaryText)
                                .font(.caption)
                            Text(transfer.type == .boutique ? "Boutique Order" : "Vendor Order")
                                .font(.caption.weight(.medium))
                                .foregroundColor(.appSecondaryText)
                        }
                        
                        Text(displayNames)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.appPrimaryText)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(totalQuantity)")
                            .font(.title2.bold())
                            .foregroundColor(.appAccent)
                        Text(totalQuantity == 1 ? "unit" : "units")
                            .font(.caption2.weight(.medium))
                            .foregroundColor(.appSecondaryText)
                            .textCase(.uppercase)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.appAccent.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Divider()
                
                // Footer: Routing
                HStack(spacing: 6) {
                    Image(systemName: "location.circle.fill")
                        .foregroundColor(.appSecondaryText)
                        .font(.caption)
                    Text("\(transfer.fromLocation)")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.appPrimaryText)
                    
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundColor(.appSecondaryText)
                        .padding(.horizontal, 2)
                        
                    Text("\(transfer.toLocation)")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.appPrimaryText)
                }
                .padding(.top, 2)
            }
        }
    }
    
    private func statusColor(_ status: TransferStatus) -> Color {
        switch status {
        case .pending, .approved: return .orange
        case .placed: return .blue
        case .dispatched, .inTransit: return .blue
        case .delivered, .received: return .green
        case .returned, .rejected: return .red
        }
    }
}

// Basic form for Create PO
struct CreatePOView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var prefilledSKU: String?
    
    @State private var sku: String = "Gold Necklace"
    @State private var quantity: String = "1"
    @State private var vendor: String = "Aurum Suppliers"
    
    let availableProducts = ["Gold Necklace", "Diamond Ring", "Silver Bracelet", "Leather Handbag", "Rolex Submariner"]
    let availableVendors = ["Aurum Suppliers", "Swiss Timers", "Acme Logistics", "Lux Group"]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Vendor Order Details")) {
                    Picker("Vendor", selection: $vendor) {
                        ForEach(availableVendors, id: \.self) { v in
                            Text(v).tag(v)
                        }
                    }
                    
                    Picker("SKU", selection: $sku) {
                        ForEach(availableProducts, id: \.self) { p in
                            Text(p).tag(p)
                        }
                    }
                    
                    TextField("Quantity", text: $quantity).keyboardType(.numberPad)
                }
            }
            .navigationTitle("Create Purchase Order")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        prefilledSKU = nil
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(CatalogTheme.primaryText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Order") {
                        submitOrder()
                    }
                    .foregroundColor(CatalogTheme.primaryText)
                }
            }
            .onAppear {
                if let prefill = prefilledSKU, availableProducts.contains(prefill) {
                    self.sku = prefill
                }
            }
        }
    }
    
    private func submitOrder() {
        let newReq = Transfer(type: .vendor, orderId: "PO-\(Int.random(in: 1000...9999))", fromLocation: vendor, toLocation: "Warehouse", status: .pending, batchNumber: "NEW", items: [TransferItem(productName: sku, quantity: Int(quantity) ?? 1)], isAdminApproved: false)
        InventoryEngine.shared.demands.append(newReq)
        
        prefilledSKU = nil
        presentationMode.wrappedValue.dismiss()
    }
}
