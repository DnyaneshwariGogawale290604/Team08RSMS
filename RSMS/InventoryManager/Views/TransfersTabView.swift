import SwiftUI

public struct TransfersTabView: View {
    @StateObject private var viewModel = TransfersViewModel()
    @Binding var selectedTab: Int
    @Binding var prefilledSKUMagic: String?

    @State private var selectedSection: Int = 1   // default to Pick Lists (most active)
    @State private var showingCreatePO = false

    @State private var pickListForDispatch: PickListGroup? = nil
    @State private var lastASN: String? = nil
    @State private var showASNToast = false

    // Exceptions & Issues
    @StateObject private var exceptionEngine = ExceptionEngine.shared
    @State private var selectedIssueShipment: Shipment? = nil
    @State private var selectedGRNForShipment: GoodsReceivedNote? = nil
    @State private var selectedProofImageUrl: String? = nil
    @State private var isShowingIssueModal: Bool = false

    @State private var showMainErrorAlert: Bool = false
    @State private var poPrefilledProductId: UUID? = nil

    // PO detail
    @State private var selectedPO: VendorOrder? = nil

    // Search and Filters
    @State private var searchText: String = ""
    @State private var poStatusFilter: String = "All"
    @State private var pickListStatusFilter: String = "All"
    @State private var shipmentStatusFilter: String = "All"

    let poStatuses = ["All", "Pending", "In_Transit", "Delivered", "Cancelled"]
    let pickListStatuses = ["All", "Ready to Pick", "Cannot Fulfill"]
    let shipmentStatuses = ["All", "In Transit", "Delivered", "Pending"]

    public init(selectedTab: Binding<Int>, prefilledSKUMagic: Binding<String?>) {
        self._selectedTab = selectedTab
        self._prefilledSKUMagic = prefilledSKUMagic
    }

    public var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Section picker
                AppSegmentedControl(
                    options: [
                        AppSegmentedOption(id: 0, title: "Purchase Orders", badge: "\(viewModel.vendorOrders.count)"),
                        AppSegmentedOption(id: 1, title: "Pick Lists", badge: "\(viewModel.pickLists.count)"),
                        AppSegmentedOption(id: 2, title: "Shipments Out", badge: "\(viewModel.shipmentsOut.count)")
                    ],
                    selection: $selectedSection
                )
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
        .navigationBarTitleDisplayMode(.large)
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
        .sheet(item: $pickListForDispatch) { group in
            ShipmentDetailsSheet(group: group) { asn in
                lastASN = asn
                withAnimation(.spring()) { showASNToast = true }
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
        .searchable(text: $searchText, prompt: "Search by ID, product, or vendor...")
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                filterMenu
                InventoryManagerProfileButton()
            }
        }
        .alert("Error", isPresented: $showMainErrorAlert) {
            Button("OK", role: .cancel) { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "An unknown error occurred.")
        }
        .sheet(isPresented: $isShowingIssueModal) {
            if let shipment = selectedIssueShipment {
                IssueResolutionModal(
                    shipment: shipment,
                    grn: selectedGRNForShipment,
                    proofImageUrl: selectedProofImageUrl
                ) {
                    Task {
                        do {
                            if let grn = selectedGRNForShipment {
                                try await viewModel.reshipMissingItems(for: shipment, grn: grn)
                            } else {
                                // Fallback: just reset shipment status (no GRN record)
                                try await RequestService.shared.resolveShipmentIssue(
                                    shipmentId: shipment.id,
                                    grnId: UUID() // dummy, will be best-effort delete
                                )
                                await viewModel.loadData()
                            }
                            isShowingIssueModal = false
                        } catch {
                            print("Error resolving: \(error)")
                            isShowingIssueModal = false
                        }
                    }
                }
            }
        }
    }

    // MARK: - ① Purchase Orders

    @ViewBuilder
    private func purchaseOrdersSection() -> some View {
        let filtered = viewModel.vendorOrders.filter { order in
            let matchesSearch = searchText.isEmpty ||
                "PO-\(order.id.uuidString.prefix(6).uppercased())".localizedCaseInsensitiveContains(searchText) ||
                (order.product?.name ?? "").localizedCaseInsensitiveContains(searchText) ||
                (order.vendor?.name ?? "").localizedCaseInsensitiveContains(searchText)
            
            let matchesStatus = poStatusFilter == "All" || order.status?.lowercased() == poStatusFilter.lowercased()
            
            return matchesSearch && matchesStatus
        }

        if filtered.isEmpty {
            emptyState(icon: "shippingbox", title: "No Purchase Orders", message: searchText.isEmpty ? "Tap + to create a PO to a vendor for restocking." : "No results match your search.")
        } else {
            List {
                ForEach(filtered) { order in
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
        // Group requests by (storeId, productId) — same boutique + same product → merged card
        let groups: [PickListGroup] = Dictionary(
            grouping: viewModel.pickLists,
            by: { "\($0.storeId?.uuidString ?? "none")-\($0.productId?.uuidString ?? "none")" }
        )
        .values
        .map { PickListGroup(requests: $0) }
        .sorted { ($0.product?.name ?? "") < ($1.product?.name ?? "") }

        let filtered = groups.filter { group in
            let matchesSearch = searchText.isEmpty ||
                "REQ-\(group.id.uuidString.prefix(4).uppercased())".localizedCaseInsensitiveContains(searchText) ||
                (group.product?.name ?? "").localizedCaseInsensitiveContains(searchText) ||
                (group.store?.name ?? "").localizedCaseInsensitiveContains(searchText)

            let stockQty = group.productId.flatMap { viewModel.stockAvailability[$0] }
            let statusLabel: String = {
                if let qty = stockQty {
                    return qty >= group.totalQuantity ? "Ready to Pick" : "Cannot Fulfill"
                }
                return "Checking Stock..."
            }()
            let matchesStatus = pickListStatusFilter == "All" || statusLabel == pickListStatusFilter
            return matchesSearch && matchesStatus
        }

        if filtered.isEmpty {
            emptyState(
                icon: "checklist",
                title: "No Pick Lists",
                message: searchText.isEmpty ? "Approved boutique requests ready to dispatch will appear here." : "No results match your search."
            )
        } else {
            List {
                ForEach(filtered) { group in
                    pickListCard(group)
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
    private func pickListCard(_ group: PickListGroup) -> some View {
        let stockQty = group.productId.flatMap { viewModel.stockAvailability[$0] }
        let canShip: Bool? = {
            guard let qty = stockQty else { return nil }
            return qty >= group.totalQuantity
        }()
        let statusColor: Color = canShip == false ? .red : (canShip == true ? .green : .orange)
        let statusLabel: String = canShip == false ? "Cannot Fulfill" : (canShip == true ? "Ready to Pick" : "Checking...")

        ReusableCardView {
            VStack(alignment: .leading, spacing: 0) {

                // ── Top: Product name + boutique + status badge
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.product?.name ?? "Unknown Product")
                            .font(.headline)
                            .foregroundColor(.appPrimaryText)
                        if let store = group.store {
                            Label(store.name, systemImage: "storefront")
                                .font(.subheadline)
                                .foregroundColor(.appSecondaryText)
                        }
                    }
                    Spacer()
                    Text(statusLabel)
                        .font(.caption.bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(statusColor.opacity(0.12))
                        .foregroundColor(statusColor)
                        .clipShape(Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 12)

                Divider().padding(.horizontal, 16)

                // ── Metrics: Units / In Stock / Requests
                HStack(spacing: 0) {
                    metricCell(value: "\(group.totalQuantity)", label: "Units", color: .appAccent)
                    Divider().frame(height: 30)
                    Group {
                        if let qty = stockQty {
                            metricCell(value: "\(qty)", label: "In Stock",
                                       color: qty >= group.totalQuantity ? .green : .orange)
                        } else {
                            VStack(spacing: 3) {
                                ProgressView().scaleEffect(0.65)
                                Text("Stock").font(.caption2).foregroundColor(.appSecondaryText)
                            }.frame(maxWidth: .infinity)
                        }
                    }
                    Divider().frame(height: 30)
                    metricCell(value: "\(group.requests.count)",
                               label: group.requests.count > 1 ? "Merged" : "Request",
                               color: .appPrimaryText)
                }
                .padding(.vertical, 12)

                Divider().padding(.horizontal, 16)

                // ── Actions
                HStack(spacing: 10) {
                    if let can = canShip, !can {
                        Button {
                            poPrefilledProductId = group.productId
                            selectedTab = 1
                            selectedSection = 0
                            showingCreatePO = true
                        } label: {
                            Label("Create PO", systemImage: "cart.badge.plus")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.orange.opacity(0.12))
                                .foregroundColor(.orange)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button {
                            Task {
                                for req in group.requests {
                                    await viewModel.checkWarehouseStock(for: req)
                                }
                            }
                        } label: {
                            Label(canShip == true ? "Verified ✓" : "Check Stock", systemImage: "cube.box")
                                .font(.subheadline.bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(canShip == true ? Color.green.opacity(0.1) : Color.appSecondaryText.opacity(0.08))
                                .foregroundColor(canShip == true ? .green : .appSecondaryText)
                                .cornerRadius(10)
                        }
                        .buttonStyle(.plain)
                    }

                    Button { pickListForDispatch = group } label: {
                        Label(group.requests.count > 1 ? "Dispatch All" : "Dispatch",
                              systemImage: "shippingbox.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(canShip == false ? Color.gray.opacity(0.15) : Color.appAccent)
                            .foregroundColor(canShip == false ? .appSecondaryText : .white)
                            .cornerRadius(10)
                    }
                    .buttonStyle(.plain)
                    .disabled(canShip == false)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .task {
            for req in group.requests {
                if let pid = req.productId, viewModel.stockAvailability[pid] == nil {
                    await viewModel.checkWarehouseStock(for: req)
                }
            }
        }
    }

    private func metricCell(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.title3.bold()).foregroundColor(color)
            Text(label).font(.caption2).foregroundColor(.appSecondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - ③ Shipments Out

    @ViewBuilder
    private func shipmentsOutSection() -> some View {
        let filtered = viewModel.shipmentsOut.filter { shipment in
            let matchesSearch = searchText.isEmpty ||
                "SHP-\(shipment.id.uuidString.prefix(6).uppercased())".localizedCaseInsensitiveContains(searchText) ||
                (shipment.asnNumber ?? "").localizedCaseInsensitiveContains(searchText) ||
                (shipment.request?.product?.name ?? "").localizedCaseInsensitiveContains(searchText) ||
                (shipment.request?.store?.name ?? "").localizedCaseInsensitiveContains(searchText)
            
            let statusLabel: String = {
                switch shipment.status {
                case "in_transit": return "In Transit"
                case "delivered": return "Delivered"
                case "pending": return "Pending"
                default: return shipment.status.capitalized
                }
            }()
            
            let matchesStatus = shipmentStatusFilter == "All" || statusLabel == shipmentStatusFilter
            
            return matchesSearch && matchesStatus
        }

        if filtered.isEmpty {
            emptyState(icon: "arrow.up.forward.square", title: "No Outbound Shipments", message: searchText.isEmpty ? "Shipments created after dispatching pick lists will appear here." : "No results match your search.")
        } else {
            List {
                ForEach(filtered) { shipment in
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
                // Compute issue first so we can conditionally hide delivered/GRN tags
                let issueCondition = viewModel.issueCondition(forShipment: shipment)
                let issueProofUrl = viewModel.proofImageUrl(forShipment: shipment)

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
                    // Hide "Delivered" badge when issue is active
                    if issueCondition == nil {
                        shipmentStatusBadge(shipment.status)
                    }
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

                // Hide "GRN Received by Boutique" tag when issue is active
                if shipment.hasGRN == true && issueCondition == nil {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill").font(.caption).foregroundColor(.green)
                        Text("GRN Received by Boutique").font(.caption.bold()).foregroundColor(.green)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(Color.green.opacity(0.08))
                    .cornerRadius(6)
                }

                if let issue = issueCondition {
                    let label = issue == .damaged ? "Damaged Goods" : "Partial Shipment"
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.caption).foregroundColor(.red)
                        Text("Issue: \(label)").font(.caption.bold()).foregroundColor(.red)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray)
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedIssueShipment = shipment
                selectedGRNForShipment = viewModel.grn(forShipment: shipment)
                selectedProofImageUrl = viewModel.proofImageUrl(forShipment: shipment)
                isShowingIssueModal = true
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
        case "in_transit": return .blue
        case "pending": return .orange
        case "cancelled": return .red
        default: return .gray
        }
    }

    private var filterMenu: some View {
        Menu {
            Section("Status Filter") {
                switch selectedSection {
                case 0:
                    Picker("PO Status", selection: $poStatusFilter) {
                        ForEach(poStatuses, id: \.self) { Text($0.replacingOccurrences(of: "_", with: " ").capitalized).tag($0) }
                    }
                case 1:
                    Picker("Pick List Status", selection: $pickListStatusFilter) {
                        ForEach(pickListStatuses, id: \.self) { Text($0).tag($0) }
                    }
                default:
                    Picker("Shipment Status", selection: $shipmentStatusFilter) {
                        ForEach(shipmentStatuses, id: \.self) { Text($0).tag($0) }
                    }
                }
            }
        } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .foregroundColor(.appAccent)
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

import MessageUI

struct CreatePurchaseOrderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TransfersViewModel
    var prefilledProductId: UUID? = nil

    @State private var selectedVendorId: UUID? = nil
    @State private var selectedProductId: UUID? = nil
    @State private var quantityText: String = ""
    @State private var notes: String = ""
    @State private var showErrorAlert: Bool = false

    // Messaging
    @State private var showMessageComposer: Bool = false
    @State private var pendingMessage: String = ""
    @State private var pendingRecipient: String = ""
    @State private var canSendMessages: Bool = MFMessageComposeViewController.canSendText()
    private let fallbackTestPhone = "7248970296"  // Testing number

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
                            .onChange(of: quantityText) { newValue in
                                quantityText = newValue.filter { $0.isNumber }
                            }
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
                                // Build vendor SMS
                                let vendor = viewModel.brandVendors.first { $0.id == vId }
                                let product = viewModel.brandProducts.first { $0.id == pId }
                                let phone = extractPhone(from: vendor?.contactInfo, defaultPhone: fallbackTestPhone)
                                let poRef = "PO-" + String(UUID().uuidString.prefix(6)).uppercased()
                                pendingRecipient = phone
                                pendingMessage = buildVendorPOMessage(
                                    poNumber: poRef,
                                    productName: product?.name ?? "Unknown Product",
                                    quantity: qty,
                                    brandName: vendor?.name ?? "RSMS",
                                    notes: notes
                                )
                                if canSendMessages {
                                    showMessageComposer = true
                                } else {
                                    // Simulator / device without SIM — just dismiss
                                    dismiss()
                                }
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
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
            }
            .alert("Error Creating Order", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred.")
            }
            .sheet(isPresented: $showMessageComposer, onDismiss: { dismiss() }) {
                MessageComposerView(
                    recipients: [pendingRecipient],
                    body: pendingMessage
                ) { _ in
                    // Message sent / cancelled — dismiss the PO sheet
                    showMessageComposer = false
                }
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
            List {
                Section {
                    LabeledContent("Order ID") {
                        Text("PO-\(order.id.uuidString.prefix(6).uppercased())")
                            .font(.system(.body, design: .monospaced).bold())
                    }
                    LabeledContent("Status") {
                        let sc = poStatusColor(order.status ?? "pending")
                        Text((order.status ?? "pending").replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(sc.opacity(0.12))
                            .foregroundColor(sc)
                            .clipShape(Capsule())
                    }
                    if let date = order.createdAt {
                        LabeledContent("Created") {
                            Text(date.formatted(date: .long, time: .shortened))
                                .font(.caption)
                                .foregroundColor(.appSecondaryText)
                        }
                    }
                } header: {
                    Text("Summary").headingStyle()
                }

                Section {
                    LabeledContent("Name") {
                        Text(order.vendor?.name ?? "Unknown Vendor")
                    }
                    if let contact = order.vendor?.contactInfo {
                        LabeledContent("Contact") {
                            Text(contact)
                        }
                    }
                } header: {
                    Text("Vendor").headingStyle()
                }

                Section {
                    LabeledContent("Name") {
                        Text(order.product?.name ?? "Unknown Product")
                    }
                    if let cat = order.product?.category {
                        LabeledContent("Category") {
                            Text(cat)
                        }
                    }
                    LabeledContent("Quantity") {
                        Text("\(order.quantity ?? 0) units")
                            .font(.body.bold())
                            .foregroundColor(.appAccent)
                    }
                } header: {
                    Text("Product").headingStyle()
                }

                if let notes = order.notes, !notes.isEmpty {
                    Section {
                        Text(notes)
                            .font(.subheadline)
                    } header: {
                        Text("Notes").headingStyle()
                    }
                }

                if order.status?.lowercased() == "pending" || order.status?.lowercased() == "in_transit" {
                    Section {
                        Button {
                            showGRNForm = true
                        } label: {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.seal.fill")
                                Text("Receive (Generate GRN)")
                                    .fontWeight(.semibold)
                                Spacer()
                            }
                        }
                        .foregroundColor(.green)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Purchase Order")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
            }
            .sheet(isPresented: $showGRNForm) {
                VendorGRNFormSheet(vendorOrder: order) { _ in
                    dismiss()
                }
                .environmentObject(viewModel)
            }
        }
    }

    private func poStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "delivered": return .green
        case "in_transit": return .blue
        case "pending": return .orange
        case "cancelled": return .red
        default: return .gray
        }
    }
}

// MARK: - Issue Resolution Modal

struct IssueResolutionModal: View {
    @Environment(\.dismiss) private var dismiss
    let shipment: Shipment
    let grn: GoodsReceivedNote?
    let proofImageUrl: String?
    let onResolve: () -> Void
    @State private var isResolving = false

    private var issueConditionDetected: GoodsReceivedNote.GRNCondition? {
        if let g = grn, g.condition != .good { return g.condition }
        guard let notes = shipment.notes else { return nil }
        if notes.contains("ISSUE:damaged") { return .damaged }
        if notes.contains("ISSUE:partial") { return .partial }
        return nil
    }

    private var effectiveProofUrl: String? {
        proofImageUrl ?? grn?.proofImageUrl
    }

    var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Dynamic Status Banner
                        if let issue = issueConditionDetected {
                            HStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.red)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Issue Reported")
                                        .font(.system(size: 16, weight: .bold, design: .serif))
                                        .foregroundColor(.red)
                                    Text("The boutique reported a problem (\(issue.displayName)) with this shipment.")
                                        .font(.caption)
                                        .foregroundColor(.appSecondaryText)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                        } else {
                            HStack(spacing: 12) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Delivered Successfully")
                                        .font(.system(size: 16, weight: .bold, design: .serif))
                                        .foregroundColor(.green)
                                    Text("This shipment has been received by the boutique.")
                                        .font(.caption)
                                        .foregroundColor(.appSecondaryText)
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                        }
                        
                        // Details Card
                        ReusableCardView {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Shipment Details")
                                    .font(.system(size: 18, weight: .bold, design: .serif))
                                    .foregroundColor(.appPrimaryText)
                                
                                Divider()
                                
                                LabeledContent("ASN", value: shipment.asnNumber ?? "Unknown")
                                LabeledContent("Destination", value: shipment.request?.store?.name ?? "Unknown")
                                LabeledContent("Product", value: shipment.request?.product?.name ?? "Unknown")
                                LabeledContent("Ordered Quantity", value: "\(shipment.request?.requestedQuantity ?? 0) units")
                            }
                        }
                        
                        // Issue Specifics Card (Only if Issue exists)
                        if let issue = issueConditionDetected {
                            ReusableCardView {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Text("Reported Issue")
                                            .font(.system(size: 18, weight: .bold, design: .serif))
                                            .foregroundColor(.appPrimaryText)
                                        Spacer()
                                        Text(issue.displayName)
                                            .font(.caption.bold())
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(Color.orange.opacity(0.15))
                                            .foregroundColor(.orange)
                                            .clipShape(Capsule())
                                    }

                                    Divider()

                                    if let imageUrl = effectiveProofUrl, !imageUrl.isEmpty {
                                        Text("Photo Proof")
                                            .font(.subheadline.bold())
                                            .foregroundColor(.appSecondaryText)
                                        AsyncImage(url: URL(string: imageUrl)) { phase in
                                            switch phase {
                                            case .success(let image):
                                                image
                                                    .resizable()
                                                    .scaledToFill()
                                                    .frame(maxWidth: .infinity, maxHeight: 220)
                                                    .clipped()
                                                    .cornerRadius(12)
                                            case .failure:
                                                Text("Could not load image.")
                                                    .font(.caption)
                                                    .foregroundColor(.red)
                                            case .empty:
                                                Rectangle()
                                                    .fill(Color.gray.opacity(0.1))
                                                    .frame(height: 180)
                                                    .overlay(ProgressView())
                                                    .cornerRadius(12)
                                            @unknown default:
                                                EmptyView()
                                            }
                                        }
                                    } else {
                                        Label("No photo proof provided.", systemImage: "photo.slash")
                                            .font(.subheadline)
                                            .foregroundColor(.appSecondaryText)
                                    }
                                }
                            }
                        }

                        // Action Button (Only if Issue exists)
                        if issueConditionDetected != nil {
                            Button {
                                isResolving = true
                                onResolve()
                            } label: {
                                if isResolving {
                                    ProgressView().tint(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                } else {
                                    Label("Mark Resolved & Reship", systemImage: "arrow.triangle.2.circlepath")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                }
                            }
                            .background(Color.appAccent)
                            .cornerRadius(12)
                            .padding(.top, 8)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Issue Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.appPrimaryText)
                    }
                }
            }
        }
    }
}
