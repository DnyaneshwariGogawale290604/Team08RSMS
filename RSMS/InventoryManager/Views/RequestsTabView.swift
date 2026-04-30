import SwiftUI

public struct RequestsTabView: View {
    @StateObject private var viewModel = TransfersViewModel()
    @State private var selectedSection: Int = 0

    @State private var requestPendingShipment: ProductRequest? = nil
    @State private var rejectTargetRequest: ProductRequest? = nil
    @State private var showRejectAlert = false
    @State private var rejectReason: String = ""
    @State private var lastASN: String? = nil
    @State private var showASNBanner = false
    @State private var showErrorAlert = false
    @State private var selectedVendorOrder: VendorOrder? = nil
    @State private var incomingStatusFilter: String? = nil
    @State private var outgoingStatusFilter: String? = nil
    @State private var incomingSearchText = ""
    @State private var outgoingSearchText = ""

    @Binding var selectedTab: Int
    @Binding var prefilledSKUMagic: String?

    public init(selectedTab: Binding<Int>, prefilledSKUMagic: Binding<String?>) {
        self._selectedTab = selectedTab
        self._prefilledSKUMagic = prefilledSKUMagic
    }

    public var body: some View {
        NavigationView {
            ZStack(alignment: .top) {
                LinearGradient(
                    colors: [
                        Color.appBackground,
                        Color.luxurySurface.opacity(0.42),
                        Color.appBackground
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    AppSegmentedControl(
                        options: [
                            AppSegmentedOption(id: 0, title: "Incoming", badge: "\(viewModel.pendingRequests.count)"),
                            AppSegmentedOption(id: 1, title: "Outgoing", badge: "\(viewModel.vendorOrders.count)")
                        ],
                        selection: $selectedSection
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 10)

                    if viewModel.isLoading {
                        Spacer()
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .appAccent))
                        Spacer()
                    } else if selectedSection == 0 {
                        incomingRequestsSection
                    } else {
                        outgoingRequestsSection
                    }
                }

                if showASNBanner, let asn = lastASN {
                    asnToastBanner(asn: asn)
                        .padding(.top, 8)
                }
            }
            .navigationTitle("Requests")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    InventoryManagerProfileButton()
                }
            }
            .task { await viewModel.loadData() }
            .refreshable { await viewModel.loadData() }
            .onReceive(NotificationCenter.default.publisher(for: .inventoryManagerDataDidChange)) { _ in
                Task { await viewModel.loadData() }
            }
            .onChange(of: viewModel.errorMessage) { newValue in
                if newValue != nil {
                    showErrorAlert = true
                }
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred.")
            }
            .sheet(item: $requestPendingShipment) { req in
                ShipmentDetailsSheet(group: PickListGroup(requests: [req])) { asn in
                    lastASN = asn
                    withAnimation { showASNBanner = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation { showASNBanner = false }
                    }
                }
            }
            .sheet(item: $selectedVendorOrder) { order in
                VendorGRNFormSheet(vendorOrder: order) { grn in
                    lastASN = grn
                    withAnimation { showASNBanner = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                        withAnimation { showASNBanner = false }
                    }
                }
                .environmentObject(viewModel)
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

    private let incomingStatuses: [(label: String, value: String?)] = [
        ("All", nil),
        ("Pending", "pending"),
        ("Approved", "approved"),
        ("Shipped", "shipped"),
        ("Rejected", "rejected")
    ]

    private let outgoingStatuses: [(label: String, value: String?)] = [
        ("All", nil),
        ("Pending", "pending"),
        ("In Transit", "in_transit"),
        ("Delivered", "delivered")
    ]

    private var filteredIncomingRequests: [ProductRequest] {
        viewModel.pendingRequests.filter { request in
            let matchesStatus = incomingStatusFilter == nil || request.status == incomingStatusFilter
            let query = incomingSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let haystacks = [
                request.product?.name ?? "",
                request.store?.name ?? "",
                request.id.uuidString,
                request.status
            ]
            let matchesSearch = query.isEmpty || haystacks.contains { $0.localizedCaseInsensitiveContains(query) }
            return matchesStatus && matchesSearch
        }
    }

    private var filteredOutgoingOrders: [VendorOrder] {
        viewModel.vendorOrders.filter { order in
            let status = (order.status ?? "").lowercased()
            let matchesStatus = outgoingStatusFilter == nil || status == outgoingStatusFilter
            let query = outgoingSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let haystacks = [
                order.product?.name ?? "",
                order.vendor?.name ?? "",
                order.id.uuidString,
                order.status ?? ""
            ]
            let matchesSearch = query.isEmpty || haystacks.contains { $0.localizedCaseInsensitiveContains(query) }
            return matchesStatus && matchesSearch
        }
    }

    private var pendingIncomingCount: Int {
        viewModel.pendingRequests.filter { $0.status == "pending" }.count
    }

    private var approvedIncomingCount: Int {
        viewModel.pendingRequests.filter { $0.status == "approved" }.count
    }

    private var incomingUnitsTotal: Int {
        filteredIncomingRequests.reduce(0) { $0 + $1.requestedQuantity }
    }

    private var outgoingTransitCount: Int {
        viewModel.vendorOrders.filter { ($0.status ?? "").lowercased() == "in_transit" }.count
    }

    private var outgoingDeliveredCount: Int {
        viewModel.vendorOrders.filter { ($0.status ?? "").lowercased() == "delivered" }.count
    }

    private var outgoingUnitsTotal: Int {
        filteredOutgoingOrders.reduce(0) { $0 + ($1.quantity ?? 0) }
    }

    private var incomingRequestsSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                queueOverviewCard(
                    metrics: [
                        QueueMetric(value: "\(pendingIncomingCount)", label: "pending"),
                        QueueMetric(value: "\(approvedIncomingCount)", label: "approved"),
                        QueueMetric(value: "\(incomingUnitsTotal)", label: "units shown")
                    ]
                )

                searchField(
                    text: $incomingSearchText,
                    prompt: "Search request, product, or boutique"
                )

                filterChipsRow(statuses: incomingStatuses, selected: $incomingStatusFilter)

                sectionHeader(
                    title: "Requests",
                    subtitle: "\(filteredIncomingRequests.count) visible"
                )

                if filteredIncomingRequests.isEmpty {
                    EmptyStateView(
                        icon: "tray",
                        title: "No Requests",
                        message: "No incoming requests match your current search or status filter."
                    )
                    .padding(.top, 32)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredIncomingRequests) { request in
                            incomingRequestCard(request: request)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
    }

    private var outgoingRequestsSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                queueOverviewCard(
                    metrics: [
                        QueueMetric(value: "\(outgoingTransitCount)", label: "in transit"),
                        QueueMetric(value: "\(outgoingDeliveredCount)", label: "delivered"),
                        QueueMetric(value: "\(outgoingUnitsTotal)", label: "units shown")
                    ]
                )

                searchField(
                    text: $outgoingSearchText,
                    prompt: "Search PO, product, or vendor"
                )

                filterChipsRow(statuses: outgoingStatuses, selected: $outgoingStatusFilter)

                sectionHeader(
                    title: "Purchase Orders",
                    subtitle: "\(filteredOutgoingOrders.count) visible"
                )

                if filteredOutgoingOrders.isEmpty {
                    EmptyStateView(
                        icon: "shippingbox",
                        title: "No Vendor Orders",
                        message: "No outgoing orders match your current search or status filter."
                    )
                    .padding(.top, 32)
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredOutgoingOrders) { order in
                            vendorOrderCard(for: order)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 28)
        }
    }

    @ViewBuilder
    private func queueOverviewCard(metrics: [QueueMetric]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                ForEach(metrics) { metric in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(metric.value)
                            .font(.system(size: 20, weight: .bold, design: .serif))
                            .foregroundColor(.white)
                        Text(metric.label.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(0.7)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, minHeight: 102, alignment: .center)
        .background(
            LinearGradient(
                colors: [Color.luxuryDeepAccent, Color.appAccent, Color(hex: "#8C6A70")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 16, x: 0, y: 10)
    }

    @ViewBuilder
    private func searchField(text: Binding<String>, prompt: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.appSecondaryText)

            TextField(prompt, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !text.wrappedValue.isEmpty {
                Button {
                    text.wrappedValue = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.appSecondaryText.opacity(0.7))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.appCard.opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
    }

    @ViewBuilder
    private func filterChipsRow(
        statuses: [(label: String, value: String?)],
        selected: Binding<String?>
    ) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(statuses, id: \.label) { chip in
                    let isSelected = selected.wrappedValue == chip.value
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selected.wrappedValue = chip.value
                        }
                    } label: {
                        Text(chip.label)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(isSelected ? .white : .appAccent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                Capsule()
                                    .fill(isSelected ? Color.appAccent : Color.white.opacity(0.96))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? Color.clear : Color.appBorder, lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(isSelected ? 0.08 : 0.03), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func sectionHeader(title: String, subtitle: String) -> some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 19, weight: .bold, design: .serif))
                    .foregroundColor(.appPrimaryText)

                Text(subtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.appSecondaryText)
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func incomingRequestCard(request: ProductRequest) -> some View {
        let stockQty = request.productId.flatMap { viewModel.stockAvailability[$0] }

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(request.product?.name ?? "Unknown Product")
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundColor(.appPrimaryText)

                    Text(request.store?.name ?? "Unknown Boutique")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.appSecondaryText)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    statusBadge(for: request.status)
                    Text(shortRequestID(request.id))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.appSecondaryText)
                }
            }

            HStack(spacing: 10) {
                compactInfoPill(title: "Quantity", value: "\(request.requestedQuantity)")
                compactInfoPill(title: "Requested", value: shortDate(request.requestDate))
                if let qty = stockQty {
                    compactInfoPill(
                        title: "Stock",
                        value: "\(qty)",
                        accent: qty >= request.requestedQuantity ? .green : .orange,
                        highlighted: true
                    )
                }
            }

            if request.status == "approved" {
                inlineBanner(
                    icon: "shippingbox.fill",
                    text: "Accepted and ready to dispatch from Workflows."
                )
            } else if request.status == "rejected" {
                inlineBanner(
                    icon: "xmark.circle.fill",
                    text: request.rejectionReason ?? "Rejected by Inventory Manager",
                    color: .red
                )
            } else if request.status == "shipped" {
                inlineBanner(
                    icon: "checkmark.seal.fill",
                    text: "Shipment has already been sent to the boutique.",
                    color: .green
                )
            }

            actionButtons(for: request)
        }
        .padding(18)
        .background(Color.appCard.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
    }

    @ViewBuilder
    private func vendorOrderCard(for order: VendorOrder) -> some View {
        let rawStatus = (order.status ?? "").lowercased()
        let statusText: String = {
            if rawStatus == "in_transit" { return "In Transit" }
            if rawStatus == "delivered" { return "Delivered" }
            return order.status?.capitalized ?? "Unknown"
        }()
        let statusColor: Color = {
            if rawStatus == "in_transit" { return .blue }
            if rawStatus == "delivered" { return .green }
            if rawStatus == "pending" { return .orange }
            return .gray
        }()

        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(order.product?.name ?? "Unknown Product")
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundColor(.appPrimaryText)

                    Text(order.vendor?.name ?? "Unknown Vendor")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.appSecondaryText)
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 6) {
                    stockBadge(text: statusText, color: statusColor)
                    Text(shortPOID(order.id))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.appSecondaryText)
                }
            }

            HStack(spacing: 10) {
                compactInfoPill(title: "Units", value: "\(order.quantity ?? 0)")
                compactInfoPill(title: "Created", value: shortDate(order.createdAt))
                if rawStatus == "in_transit" {
                    compactInfoPill(title: "Action", value: "Receive", accent: .blue, highlighted: true)
                }
            }

            if rawStatus == "in_transit" {
                Button {
                    selectedVendorOrder = order
                } label: {
                    Label("Receive and Generate GRN", systemImage: "shippingbox.and.arrow.backward")
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.appAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(Color.appCard.opacity(0.97))
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.appBorder, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
    }

    @ViewBuilder
    private func compactInfoPill(
        title: String,
        value: String,
        accent: Color = .appAccent,
        highlighted: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(0.6)
                .foregroundColor(.appSecondaryText)
            Text(value)
                .font(.system(size: 14, weight: .bold, design: .serif))
                .foregroundColor(highlighted ? accent : .appPrimaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(Color.luxurySurface.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func inlineBanner(icon: String, text: String, color: Color = .blue) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func actionButtons(for request: ProductRequest) -> some View {
        switch request.status {
        case "rejected":
            EmptyView()

        case "approved":
            Button {
                requestPendingShipment = request
            } label: {
                Label("Create Shipment", systemImage: "box.truck.fill")
                    .font(.system(size: 14, weight: .bold, design: .serif))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.appAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

        case "shipped":
            EmptyView()

        default:
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        rejectTargetRequest = request
                        showRejectAlert = true
                    } label: {
                        Text("Reject")
                            .font(.system(size: 14, weight: .bold, design: .serif))
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Button {
                        Task {
                            await viewModel.acceptRequest(request: request)
                        }
                    } label: {
                        Text("Accept")
                            .font(.system(size: 14, weight: .bold, design: .serif))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.appAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }

                Text("Accepted requests move to Workflows → Pick Lists for dispatch.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.appSecondaryText)
            }
        }
    }

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

        stockBadge(text: label, color: color)
    }

    @ViewBuilder
    private func stockBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private func asnToastBanner(asn: String) -> some View {
        VStack {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Reference Generated")
                        .font(.caption.bold())
                        .foregroundColor(.appPrimaryText)
                    Text(asn)
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundColor(.appAccent)
                }

                Spacer()

                Button {
                    withAnimation { showASNBanner = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.appSecondaryText)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.appCard)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.08), radius: 12, x: 0, y: 6)
            .padding(.horizontal, 16)

            Spacer()
        }
    }

    private func shortRequestID(_ id: UUID) -> String {
        "REQ-\(id.uuidString.prefix(5).uppercased())"
    }

    private func shortPOID(_ id: UUID) -> String {
        "PO-\(id.uuidString.prefix(5).uppercased())"
    }

    private func shortDate(_ date: Date?) -> String {
        guard let date else { return "Unknown" }
        return requestDateFormatter.string(from: date)
    }

    private var requestDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM"
        return formatter
    }
}

private struct QueueMetric: Identifiable {
    let id = UUID()
    let value: String
    let label: String
}
