import SwiftUI

public struct RequestsTabView: View {
    @StateObject private var viewModel = TransfersViewModel()
    @State private var selectedSection: Int = 0  // 0: Incoming (Boutique), 1: Outgoing (Vendor)

    // State for 2-step flow
    @State private var requestPendingShipment: ProductRequest? = nil
    @State private var showShipmentSheet = false
    @State private var stockCheckResults: [UUID: Bool] = [:]   // requestId → canShip
    @State private var rejectTargetRequest: ProductRequest? = nil
    @State private var showRejectAlert = false
    @State private var rejectReason: String = ""
    @State private var lastASN: String? = nil
    @State private var showASNBanner = false

    public init() {}

    public var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 0) {
                    Picker("Requests", selection: $selectedSection) {
                        Text("Incoming (Boutique)").tag(0)
                        Text("Outgoing (Vendor)").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding()

                    if viewModel.isLoading {
                        Spacer()
                        ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                        Spacer()
                    } else if selectedSection == 0 {
                        incomingRequestsSection()
                    } else {
                        outgoingRequestsSection()
                    }
                }

                // ASN Banner overlay
                if showASNBanner, let asn = lastASN {
                    asnToastBanner(asn: asn)
                }
            }
            .navigationTitle("Requests")
            .navigationBarTitleDisplayMode(.inline)
            .task { await viewModel.loadData() }
            .refreshable { await viewModel.loadData() }
            .sheet(item: $requestPendingShipment) { req in
                ShipmentDetailsSheet(request: req) { asn in
                    lastASN = asn
                    withAnimation { showASNBanner = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation { showASNBanner = false }
                    }
                }
            }
            .alert("Reject Request", isPresented: $showRejectAlert) {
                TextField("Reason (optional)", text: $rejectReason)
                Button("Reject", role: .destructive) {
                    if let req = rejectTargetRequest {
                        Task {
                            await viewModel.rejectRequest(
                                request: req,
                                reason: rejectReason.isEmpty ? "Rejected by Inventory Manager" : rejectReason
                            )
                            rejectReason = ""
                        }
                    }
                }
                Button("Cancel", role: .cancel) { rejectReason = "" }
            } message: {
                Text("Please provide a reason for rejection.")
            }
        }
    }

    // MARK: - Incoming Requests Section

    @ViewBuilder
    private func incomingRequestsSection() -> some View {
        let incoming = viewModel.pendingRequests
        if incoming.isEmpty {
            Spacer()
            EmptyStateView(icon: "tray", title: "No Pending Requests", message: "All boutique requests have been actioned. Check Workflows → Pick Lists for approved ones.")
            Spacer()
        } else {
            List {
                ForEach(incoming) { request in
                    incomingRequestCard(request: request)
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
    private func incomingRequestCard(request: ProductRequest) -> some View {
        let canShip = stockCheckResults[request.id]
        let stockQty = request.productId.flatMap { viewModel.stockAvailability[$0] }

        ReusableCardView {
            VStack(alignment: .leading, spacing: 10) {

                // Header: REQ ID + Status badge
                HStack {
                    Text("REQ-\(request.id.uuidString.prefix(5).uppercased())")
                        .font(.headline).foregroundColor(.appPrimaryText)
                    Spacer()
                    statusBadge(for: request.status)
                }

                // ASN badge (if shipped)
                if request.status == "approved" {
                    HStack(spacing: 4) {
                        Image(systemName: "shippingbox.fill")
                            .font(.caption2)
                        Text("Shipment In Transit")
                            .font(.caption2.bold())
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .clipShape(Capsule())
                }

                Text("From: \(request.store?.name ?? "Unknown Boutique")")
                    .font(.subheadline)
                    .foregroundColor(.appSecondaryText)

                Divider()

                HStack {
                    Text("\(request.requestedQuantity)× \(request.product?.name ?? "Unknown Product")")
                        .font(.body)
                    Spacer()
                    if let qty = stockQty {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(qty) in stock")
                                .font(.caption.bold())
                                .foregroundColor(qty >= request.requestedQuantity ? .green : .orange)
                        }
                    }
                }

                // Low stock warning
                if let canShip = canShip, !canShip {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption)
                        Text("Insufficient stock — consider placing a vendor order first")
                            .font(.caption)
                    }
                    .foregroundColor(.orange)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                }

                Divider()

                // Action buttons based on status
                actionButtons(for: request, canShip: canShip)
            }
        }
    }

    @ViewBuilder
    private func actionButtons(for request: ProductRequest, canShip: Bool?) -> some View {
        switch request.status {
        case "rejected":
            HStack(spacing: 4) {
                Image(systemName: "xmark.circle.fill").font(.caption)
                Text("Rejected: \(request.rejectionReason ?? "No reason given")")
                    .font(.caption)
            }
            .foregroundColor(.red)

        case "approved":
            // Approved but not yet shipped → show "Ship Now" button
            Button {
                requestPendingShipment = request
            } label: {
                Label("Ship Now", systemImage: "shippingbox.fill")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }

        case "shipped":
            HStack(spacing: 4) {
                Image(systemName: "checkmark.seal.fill").font(.caption)
                Text("Shipped")
                    .font(.caption.bold())
            }
            .foregroundColor(.green)
            .frame(maxWidth: .infinity, alignment: .leading)

        default: // "pending"
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    // Reject button
                    Button {
                        rejectTargetRequest = request
                        showRejectAlert = true
                    } label: {
                        Text("Reject")
                            .font(.caption.bold())
                            .foregroundColor(.red)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.red, lineWidth: 1))
                    }

                    // Accept button — moves to Pick Lists
                    Button {
                        Task {
                            let hasSufficientStock = await viewModel.checkWarehouseStock(for: request)
                            stockCheckResults[request.id] = hasSufficientStock
                            await viewModel.acceptRequest(request: request)
                        }
                    } label: {
                        Text("Accept → Pick List")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(canShip == false ? Color.orange : Color.green)
                            .cornerRadius(8)
                    }
                }
                // Hint
                Text("Accepting moves this to Workflows → Pick Lists for dispatch.")
                    .font(.caption2)
                    .foregroundColor(.appSecondaryText)
            }
        }
    }

    // MARK: - Outgoing Vendor Requests Section

    @ViewBuilder
    private func outgoingRequestsSection() -> some View {
        let outgoing = viewModel.vendorOrders
        if outgoing.isEmpty {
            Spacer()
            EmptyStateView(icon: "shippingbox", title: "No Vendor Orders", message: "No outgoing purchase orders yet. Go to Workflows → Purchase Orders to create one.")
            Spacer()
        } else {
            List {
                ForEach(outgoing) { order in
                    ReusableCardView {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("PO-\(order.id.uuidString.prefix(5).uppercased())")
                                    .font(.system(.subheadline, design: .monospaced).bold())
                                    .foregroundColor(.appPrimaryText)
                                Spacer()
                                let sc: Color = order.status == "received" ? .green : (order.status == "pending" ? .orange : .gray)
                                Text(order.status?.capitalized ?? "Pending")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(sc.opacity(0.15))
                                    .foregroundColor(sc)
                                    .clipShape(Capsule())
                            }
                            if let vendor = order.vendor {
                                Label(vendor.name, systemImage: "building.2")
                                    .font(.subheadline)
                                    .foregroundColor(.appSecondaryText)
                            }
                            if let product = order.product {
                                Label(product.name, systemImage: "tag")
                                    .font(.subheadline)
                                    .foregroundColor(.appSecondaryText)
                            }
                            HStack {
                                Image(systemName: "number").font(.caption)
                                Text("\(order.quantity ?? 0) units").font(.caption)
                            }
                            .foregroundColor(.appSecondaryText)
                        }
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

    // MARK: - Helpers

    @ViewBuilder
    private func statusBadge(for status: String) -> some View {
        let (color, label): (Color, String) = {
            switch status {
            case "approved": return (.blue, "Approved")
            case "pending": return (.orange, "Pending")
            case "rejected": return (.red, "Rejected")
            case "shipped": return (.green, "Shipped")
            default: return (.gray, status.capitalized)
            }
        }()

        Text(label)
            .font(.caption.bold())
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func asnToastBanner(asn: String) -> some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("ASN Generated")
                        .font(.caption.bold())
                        .foregroundColor(.appPrimaryText)
                    Text(asn)
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundColor(.appAccent)
                }
                Spacer()
                Button { withAnimation { showASNBanner = false } } label: {
                    Image(systemName: "xmark").font(.caption).foregroundColor(.appSecondaryText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appCard)
            .cornerRadius(14)
            .shadow(radius: 10)
            .padding(.horizontal, 16)
            Spacer()
        }
        .padding(.top, 8)
    }
}
