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
            CreatePOView(prefilledSKU: $prefilledSKUMagic, brandVendors: viewModel.brandVendors)
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
        if viewModel.shipmentsOut.isEmpty {
            Spacer()
            Text("No outbound shipments yet.")
                .foregroundColor(.appSecondaryText)
            Spacer()
        } else {
            List {
                ForEach(viewModel.shipmentsOut) { shipment in
                    shipmentOutCard(for: shipment)
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
    private func shipmentOutCard(for shipment: Shipment) -> some View {
        ReusableCardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if let asn = shipment.asnNumber {
                            Text(asn)
                                .font(.system(.caption, design: .monospaced).bold())
                                .foregroundColor(.appAccent)
                        }
                        Text(shipment.request?.product?.name ?? "Shipment")
                            .font(.headline)
                            .foregroundColor(.appPrimaryText)
                    }
                    Spacer()
                    shipmentStatusBadge(shipment.status)
                }

                if let carrier = shipment.carrier {
                    HStack(spacing: 4) {
                        Image(systemName: "shippingbox").font(.caption).foregroundColor(.appSecondaryText)
                        Text(carrier).font(.subheadline).foregroundColor(.appSecondaryText)
                        if let tracking = shipment.trackingNumber {
                            Text("· \(tracking)").font(.caption).foregroundColor(.appSecondaryText)
                        }
                    }
                }

                if let eta = shipment.estimatedDelivery {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar").font(.caption).foregroundColor(.appSecondaryText)
                        Text("ETA: \(eta)").font(.caption).foregroundColor(.appSecondaryText)
                    }
                }

                if shipment.hasGRN == true {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill").font(.caption).foregroundColor(.green)
                        Text("GRN Received").font(.caption.bold()).foregroundColor(.green)
                    }
                }
            }
        }
    }

    private func shipmentStatusBadge(_ status: String) -> some View {
        let (color, label): (Color, String) = {
            switch status {
            case "in_transit": return (.blue, "In Transit")
            case "delivered": return (.green, "Delivered")
            case "pending": return (.orange, "Pending")
            default: return (.gray, status.capitalized)
            }
        }()
        return Text(label)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
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
/// Create Purchase Order form — uses brand-scoped vendor list from TransfersViewModel.
struct CreatePOView: View {
    @Environment(\.presentationMode) var presentationMode
    @Binding var prefilledSKU: String?
    /// Passed in from parent TransfersTabView to access brand-scoped vendors.
    let brandVendors: [Vendor]

    @State private var sku: String = ""
    @State private var quantity: String = "1"
    @State private var selectedVendorId: UUID? = nil

    private var selectedVendorName: String {
        brandVendors.first(where: { $0.id == selectedVendorId })?.name ?? "Select Vendor"
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Vendor Order Details")) {
                    // Brand-scoped vendor picker
                    if brandVendors.isEmpty {
                        Text("No vendors available for this brand.")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        Picker("Vendor", selection: $selectedVendorId) {
                            Text("Select Vendor").tag(UUID?.none)
                            ForEach(brandVendors) { vendor in
                                Text(vendor.name).tag(Optional(vendor.id))
                            }
                        }
                    }

                    TextField("Product / SKU", text: $sku)

                    TextField("Quantity", text: $quantity)
#if canImport(UIKit)
                        .keyboardType(.numberPad)
#endif
                }
            }
            .navigationTitle("Create Purchase Order")
            .navigationBarItems(
                leading: Button(action: {
                    prefilledSKU = nil
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                },
                trailing: Button(action: { submitOrder() }) {
                    Text("Submit").font(.headline)
                }
                .disabled(sku.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedVendorId == nil)
            )
            .onAppear {
                if let prefill = prefilledSKU {
                    self.sku = prefill
                }
                if selectedVendorId == nil {
                    selectedVendorId = brandVendors.first?.id
                }
            }
        }
    }

    private func submitOrder() {
        let vendorName = selectedVendorName
        let newReq = Transfer(
            type: .vendor,
            orderId: "PO-\(Int.random(in: 1000...9999))",
            fromLocation: vendorName,
            toLocation: "Warehouse",
            status: .pending,
            batchNumber: "NEW",
            items: [TransferItem(productName: sku, quantity: Int(quantity) ?? 1)],
            isAdminApproved: false
        )
        InventoryEngine.shared.demands.append(newReq)
        prefilledSKU = nil
        presentationMode.wrappedValue.dismiss()
    }
}
