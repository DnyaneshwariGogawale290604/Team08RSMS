import SwiftUI

public struct TransfersTabView: View {
    @StateObject private var viewModel = TransfersViewModel()
    @Binding var selectedTab: Int
    @Binding var prefilledSKUMagic: String?

    @State private var selectedSection: Int = 1   // default to Pick Lists (most active)
    @State private var showingCreatePO = false

    // Pick list dispatch
    @State private var pickListForDispatch: ProductRequest? = nil
    @State private var lastASN: String? = nil
    @State private var showASNToast = false

    @State private var showMainErrorAlert: Bool = false
    @State private var poPrefilledProductId: UUID? = nil

    // PO detail
    @State private var selectedPO: VendorOrder? = nil

    public init(selectedTab: Binding<Int>, prefilledSKUMagic: Binding<String?>) {
        self._selectedTab = selectedTab
        self._prefilledSKUMagic = prefilledSKUMagic
    }

    public var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Section picker
                Picker("Section", selection: $selectedSection) {
                    Text("Purchase Orders").tag(0)
                    Text("Pick Lists").tag(1)
                    Text("Shipments Out").tag(2)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if viewModel.isLoading && viewModel.pickLists.isEmpty && viewModel.vendorOrders.isEmpty {
                    Spacer()
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                    Spacer()
                } else {
                    switch selectedSection {
                    case 0: purchaseOrdersSection()
                    case 1: pickListsSection()
                    default: shipmentsOutSection()
                    }
                }
            }

            // FAB — only visible on Purchase Orders tab
            if selectedSection == 0 {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button { showingCreatePO = true } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .padding(20)
                                .background(Color.appAccent)
                                .clipShape(Circle())
                                .shadow(color: Color.appAccent.opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                    }
                }
            }

            // ASN Toast
            if showASNToast, let asn = lastASN {
                asnToast(asn: asn)
                    .transition(.move(edge: .top).combined(with: .opacity))
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
        .task { await viewModel.loadData() }
        .refreshable { await viewModel.loadData() }
        .onReceive(NotificationCenter.default.publisher(for: .inventoryManagerDataDidChange)) { _ in
            Task { await viewModel.loadData() }
        }
        .sheet(isPresented: $showingCreatePO) {
            CreatePurchaseOrderSheet(viewModel: viewModel, prefilledProductId: poPrefilledProductId)
        }
        .sheet(item: $pickListForDispatch) { req in
            ShipmentDetailsSheet(request: req) { asn in
                lastASN = asn
                withAnimation(.spring()) { showASNToast = true }
                // Move to Shipments Out tab once ASN is generated
                withAnimation { selectedSection = 2 }
                Task { await viewModel.loadData() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    withAnimation { showASNToast = false }
                }
            }
        }
        .sheet(item: $selectedPO) { po in
            PurchaseOrderDetailSheet(order: po, viewModel: viewModel)
        }
        .alert("Error", isPresented: $showMainErrorAlert) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
    }

    // MARK: - ① Purchase Orders

    @ViewBuilder
    private func purchaseOrdersSection() -> some View {
        if viewModel.vendorOrders.isEmpty {
            emptyState(icon: "shippingbox", title: "No Purchase Orders", message: "Tap + to create a PO to a vendor for restocking.")
        } else {
            List {
                ForEach(viewModel.vendorOrders) { order in
                    purchaseOrderCard(order)
                        .contentShape(Rectangle())
                        .onTapGesture { selectedPO = order }
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 16)
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func purchaseOrderCard(_ order: VendorOrder) -> some View {
        let statusColor = poStatusColor(order.status ?? "in_transit")
        ReusableCardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("PO-\(order.id.uuidString.prefix(6).uppercased())")
                            .font(.system(.subheadline, design: .monospaced).bold())
                            .foregroundColor(.appPrimaryText)
                        if let vendor = order.vendor {
                            Text(vendor.name)
                                .font(.caption)
                                .foregroundColor(.appSecondaryText)
                        }
                    }
                    Spacer()
                    Text((order.status ?? "pending").capitalized)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(statusColor.opacity(0.15))
                        .foregroundColor(statusColor)
                        .clipShape(Capsule())
                }

                Divider()

                HStack(spacing: 16) {
                    // Product
                    VStack(alignment: .leading, spacing: 2) {
                        Label("Product", systemImage: "tag")
                            .font(.caption2)
                            .foregroundColor(.appSecondaryText)
                        Text(order.product?.name ?? "Unknown Product")
                            .font(.subheadline.bold())
                            .foregroundColor(.appPrimaryText)
                    }
                    Spacer()
                    // Quantity
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(order.quantity ?? 0)")
                            .font(.title2.bold())
                            .foregroundColor(.appAccent)
                        Text("units")
                            .font(.caption2)
                            .foregroundColor(.appSecondaryText)
                    }
                }

                if let notes = order.notes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundColor(.appSecondaryText)
                        .lineLimit(2)
                }

                // Date
                if let date = order.createdAt {
                    Text(date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.appSecondaryText)
                }
            }
        }
    }

    // MARK: - ② Pick Lists

    @ViewBuilder
    private func pickListsSection() -> some View {
        if viewModel.pickLists.isEmpty {
            emptyState(
                icon: "checklist",
                title: "No Pick Lists",
                message: "Approved boutique requests ready to dispatch will appear here."
            )
        } else {
            List {
                ForEach(viewModel.pickLists) { request in
                    pickListCard(request)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 16)
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func pickListCard(_ request: ProductRequest) -> some View {
        let stockQty = request.productId.flatMap { viewModel.stockAvailability[$0] }
        let canShip: Bool? = {
            guard let qty = stockQty else { return nil }
            return qty >= request.requestedQuantity
        }()

        ReusableCardView {
            VStack(alignment: .leading, spacing: 10) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("REQ-\(request.id.uuidString.prefix(4).uppercased())")
                            .font(.system(.subheadline, design: .monospaced).bold())
                            .foregroundColor(.appPrimaryText)
                        Text("Boutique Order")
                            .font(.caption)
                            .foregroundColor(.appSecondaryText)
                    }
                    // Status badge
                    if canShip == false {
                        Text("Cannot Fulfill")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.red.opacity(0.12))
                            .foregroundColor(.red)
                            .clipShape(Capsule())
                    } else {
                        Text(canShip == true ? "Ready to Pick" : "Checking Stock...")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.12))
                            .foregroundColor(.blue)
                            .clipShape(Capsule())
                    }
                }

                // Product + Quantity
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(request.product?.name ?? "Unknown Product")
                            .font(.headline)
                            .foregroundColor(.appPrimaryText)
                        if let store = request.store {
                            HStack(spacing: 4) {
                                Image(systemName: "location.fill")
                                    .font(.caption2)
                                Text("→ \(store.name)")
                                    .font(.caption)
                            }
                            .foregroundColor(.appSecondaryText)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(request.requestedQuantity)")
                            .font(.title2.bold())
                            .foregroundColor(canShip == false ? .orange : .appAccent)
                        Text("UNITS")
                            .font(.caption2.bold())
                            .foregroundColor(.appSecondaryText)
                    }
                }

                // Stock availability (shown once checked)
                if let qty = stockQty {
                    HStack(spacing: 4) {
                        Image(systemName: qty >= request.requestedQuantity ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundColor(qty >= request.requestedQuantity ? .green : .orange)
                        Text("\(qty) in warehouse stock")
                            .font(.caption)
                            .foregroundColor(.appSecondaryText)
                    }
                }

                Divider()

                // Action buttons
                HStack(spacing: 10) {
                    if let can = canShip, !can {
                        // Insufficient stock -> Open Create PO sheet (same as '+' FAB)
                        Button {
                            poPrefilledProductId = request.productId
                            selectedTab = 1          // switch to Workflows tab
                            selectedSection = 0      // jump to Purchase Orders section
                            showingCreatePO = true   // open the sheet
                        } label: {
                            Label("Create PO", systemImage: "cart.badge.plus")
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.orange.opacity(0.15))
                                .foregroundColor(.orange)
                                .cornerRadius(8)
                        }
                    } else {
                        // Check Stock button
                        Button {
                            Task {
                                await viewModel.checkWarehouseStock(for: request)
                            }
                        } label: {
                            Label(canShip == true ? "Stock Verified" : "Check Stock", systemImage: "cube.box")
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(canShip == true ? Color.green.opacity(0.1) : Color.appSecondaryText.opacity(0.1))
                                .foregroundColor(canShip == true ? .green : .appSecondaryText)
                                .cornerRadius(8)
                        }
                    }

                    Spacer()

                    // Dispatch button
                    Button {
                        pickListForDispatch = request
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "shippingbox.fill")
                            Text("Dispatch")
                                .font(.caption.bold())
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(canShip == false ? Color.gray.opacity(0.5) : Color.appAccent)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .disabled(canShip == false)
                }
            }
        }
        .task {
            // Auto check stock when this card appears so we immediately know if we can fulfill
            if let pid = request.productId, viewModel.stockAvailability[pid] == nil {
                await viewModel.checkWarehouseStock(for: request)
            }
        }
    }

    // MARK: - ③ Shipments Out

    @ViewBuilder
    private func shipmentsOutSection() -> some View {
        if viewModel.shipmentsOut.isEmpty {
            emptyState(icon: "arrow.up.forward.square", title: "No Outbound Shipments", message: "Shipments created after dispatching pick lists will appear here.")
        } else {
            List {
                ForEach(viewModel.shipmentsOut) { shipment in
                    shipmentOutCard(shipment)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 16)
                }
            }
            .listStyle(.plain)
        }
    }

    @ViewBuilder
    private func shipmentOutCard(_ shipment: Shipment) -> some View {
        ReusableCardView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if let asn = shipment.asnNumber {
                            Text(asn)
                                .font(.system(.caption, design: .monospaced).bold())
                                .foregroundColor(.appAccent)
                        } else {
                            Text("SHP-\(shipment.id.uuidString.prefix(6).uppercased())")
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

                if let store = shipment.request?.store {
                    HStack(spacing: 4) {
                        Image(systemName: "storefront").font(.caption).foregroundColor(.appSecondaryText)
                        Text("To: \(store.name)").font(.subheadline).foregroundColor(.appSecondaryText)
                    }
                }

                if let carrier = shipment.carrier {
                    HStack(spacing: 4) {
                        Image(systemName: "shippingbox").font(.caption).foregroundColor(.appSecondaryText)
                        Text(carrier).font(.caption).foregroundColor(.appSecondaryText)
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

                if let qty = shipment.request?.requestedQuantity {
                    HStack(spacing: 4) {
                        Image(systemName: "number").font(.caption).foregroundColor(.appSecondaryText)
                        Text("\(qty) units").font(.caption).foregroundColor(.appSecondaryText)
                    }
                }

                if shipment.hasGRN == true {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill").font(.caption).foregroundColor(.green)
                        Text("GRN Received by Boutique").font(.caption.bold()).foregroundColor(.green)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(6)
                }
            }
        }
    }

    // MARK: - Helpers

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

    private func poStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "delivered": return .green
        case "pending", "in_transit": return .orange
        case "cancelled": return .red
        default: return .gray
        }
    }

    @ViewBuilder
    private func emptyState(icon: String, title: String, message: String) -> some View {
        Spacer()
        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(Color.appBorder)
            Text(title)
                .font(.headline)
                .foregroundColor(.appPrimaryText)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.appSecondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        Spacer()
    }

    @ViewBuilder
    private func asnToast(asn: String) -> some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill").foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ASN Generated").font(.caption.bold()).foregroundColor(.appPrimaryText)
                    Text(asn).font(.system(.caption, design: .monospaced).bold()).foregroundColor(.appAccent)
                }
                Spacer()
                Button { withAnimation { showASNToast = false } } label: {
                    Image(systemName: "xmark").font(.caption).foregroundColor(.appSecondaryText)
                }
            }
            .padding(14)
            .background(Color.appCard)
            .cornerRadius(14)
            .shadow(radius: 10)
            .padding(.horizontal, 16)
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Create Purchase Order Sheet

struct CreatePurchaseOrderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TransfersViewModel
    var prefilledProductId: UUID? = nil

    @State private var selectedVendorId: UUID? = nil
    @State private var selectedProductId: UUID? = nil
    @State private var quantityText: String = ""
    @State private var notes: String = ""
    @State private var showErrorAlert: Bool = false

    private var isValid: Bool {
        selectedVendorId != nil && selectedProductId != nil && (Int(quantityText) ?? 0) > 0
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    // Info banner
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle.fill").foregroundColor(.appAccent)
                        Text("A Purchase Order requests stock from a vendor. Once the vendor ships, mark it as Received.")
                            .font(.caption)
                            .foregroundColor(.appSecondaryText)
                    }
                    .padding(12)
                    .background(Color.appAccent.opacity(0.08))
                    .cornerRadius(10)

                    // Vendor Picker
                    formCard(title: "Vendor") {
                        if viewModel.brandVendors.isEmpty {
                            Text("No vendors — ask Corporate Admin to add vendors first.")
                                .font(.caption)
                                .foregroundColor(.orange)
                        } else {
                            Picker("Select Vendor", selection: $selectedVendorId) {
                                Text("Select Vendor").tag(UUID?.none)
                                ForEach(viewModel.brandVendors) { v in
                                    Text(v.name).tag(Optional(v.id))
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }

                    // Product Picker
                    formCard(title: "Product") {
                        if viewModel.brandProducts.isEmpty {
                            Text("No products found.").font(.caption).foregroundColor(.orange)
                        } else {
                            Picker("Select Product", selection: $selectedProductId) {
                                Text("Select Product").tag(UUID?.none)
                                ForEach(viewModel.brandProducts) { p in
                                    Text(p.name).tag(Optional(p.id))
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }

                    // Quantity
                    formCard(title: "Quantity") {
                        TextField("Units to order", text: $quantityText)
                            .multilineTextAlignment(.trailing)
                            .font(.headline)
#if canImport(UIKit)
                            .keyboardType(.numberPad)
#endif
                    }

                    // Notes
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notes (optional)")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(.appSecondaryText)
                        TextEditor(text: $notes)
                            .frame(minHeight: 70)
                            .font(.system(size: 14))
                            .padding(8)
                            .background(Color.appBackground)
                            .cornerRadius(10)
                    }
                    .padding(16)
                    .background(Color.appCard)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 0.8))

                    // Submit
                    Button {
                        Task {
                            guard let vId = selectedVendorId, let pId = selectedProductId,
                                  let qty = Int(quantityText), qty > 0 else { return }
                            let ok = await viewModel.createPurchaseOrder(vendorId: vId, productId: pId, quantity: qty, notes: notes)
                            if ok { 
                                dismiss() 
                            } else if viewModel.errorMessage != nil {
                                showErrorAlert = true
                            }
                        }
                    } label: {
                        Group {
                            if viewModel.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "plus.circle.fill")
                                    Text("Create Purchase Order")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 50)
                            .fill(isValid && !viewModel.isLoading ? Color.appAccent : Color.appBorder)
                    )
                    .disabled(!isValid || viewModel.isLoading)
                }
                .padding(20)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("New Purchase Order")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if let pid = prefilledProductId { selectedProductId = pid }
                if selectedVendorId == nil { selectedVendorId = viewModel.brandVendors.first?.id }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.appPrimaryText)
                }
            }
            .alert("Error Creating Order", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred.")
            }
        }
    }

    @ViewBuilder
    private func formCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appSecondaryText)
                .frame(minWidth: 70, alignment: .leading)
            Spacer()
            content()
                .font(.system(size: 14))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.appCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 0.8))
    }
}

// MARK: - Purchase Order Detail Sheet

struct PurchaseOrderDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let order: VendorOrder
    @ObservedObject var viewModel: TransfersViewModel
    
    @State private var showGRNForm = false

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    // Header card
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("PO-\(order.id.uuidString.prefix(6).uppercased())")
                                .font(.system(.title3, design: .monospaced).bold())
                                .foregroundColor(.appPrimaryText)
                            Spacer()
                            let sc = poStatusColor(order.status ?? "pending")
                            Text((order.status ?? "pending").capitalized)
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 5)
                                .background(sc.opacity(0.12))
                                .foregroundColor(sc)
                                .clipShape(Capsule())
                        }

                        if let date = order.createdAt {
                            Text("Created: \(date.formatted(date: .long, time: .shortened))")
                                .font(.caption)
                                .foregroundColor(.appSecondaryText)
                        }
                    }
                    .padding(16)
                    .background(Color.appCard)
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 0.8))

                    // Vendor card
                    detailCard(icon: "building.2", title: "Vendor") {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(order.vendor?.name ?? "Unknown Vendor")
                                .font(.headline).foregroundColor(.appPrimaryText)
                            if let contact = order.vendor?.contactInfo {
                                Text(contact).font(.subheadline).foregroundColor(.appSecondaryText)
                            }
                        }
                    }

                    // Product card
                    detailCard(icon: "tag", title: "Product") {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(order.product?.name ?? "Unknown Product")
                                    .font(.headline).foregroundColor(.appPrimaryText)
                                if let cat = order.product?.category {
                                    Text(cat).font(.caption).foregroundColor(.appSecondaryText)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("\(order.quantity ?? 0)")
                                    .font(.title2.bold()).foregroundColor(.appAccent)
                                Text("units").font(.caption2).foregroundColor(.appSecondaryText)
                            }
                        }
                    }

                    // Notes card
                    if let notes = order.notes, !notes.isEmpty {
                        detailCard(icon: "note.text", title: "Notes") {
                            Text(notes).font(.subheadline).foregroundColor(.appPrimaryText)
                        }
                    }

                    // Mark Received button
                    if order.status?.lowercased() == "pending" || order.status?.lowercased() == "in_transit" {
                        Button {
                            showGRNForm = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.seal.fill")
                                Text("Receive (Generate GRN)")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                        }
                        .background(RoundedRectangle(cornerRadius: 50).fill(Color.green))
                        .padding(.top, 8)
                    }
                }
                .padding(20)
            }
            .sheet(isPresented: $showGRNForm) {
                VendorGRNFormSheet(vendorOrder: order) { _ in
                    dismiss()
                }
                .environmentObject(viewModel)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Purchase Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }.foregroundColor(.appAccent)
                }
            }
        }
    }

    @ViewBuilder
    private func detailCard<Content: View>(icon: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.semibold))
                .foregroundColor(.appSecondaryText)
            content()
        }
        .padding(16)
        .background(Color.appCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 0.8))
    }

    private func poStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "delivered": return .green
        case "pending", "in_transit": return .orange
        case "cancelled": return .red
        default: return .gray
        }
    }
}
