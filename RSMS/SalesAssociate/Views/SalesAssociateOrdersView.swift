import SwiftUI
import Combine
import Supabase
import PostgREST

struct SalesAssociateOrdersView: View {
    @ObservedObject private var sessionViewModel: SessionViewModel
    private enum OrderStatusFilter: String, CaseIterable {
        case all = "All"
        case pending = "Pending"
        case completed = "Completed"
        case cancelled = "Cancelled"
    }

    @StateObject private var viewModel = SalesAssociateViewModel()
    @EnvironmentObject var orderStore: SharedOrderStore
    @State private var selectedOrder: PlacedOrder? = nil
    @State private var selectedRemoteOrder: SAOrder? = nil
    @State private var searchText = ""
    @State private var selectedStatusFilter: OrderStatusFilter = .all
    @State private var billingOrderId: UUID? = nil
    @State private var orderToCancel: SAOrder? = nil
    @State private var showNewOrder = false

    init(sessionViewModel: SessionViewModel) {
        self.sessionViewModel = sessionViewModel
    }

    fileprivate static func normalizeStatus(_ rawStatus: String?) -> String {
        let raw = (rawStatus ?? "pending").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if raw.isEmpty { return "pending" }

        switch raw {
        case "complete", "completed":
            return "completed"
        case "cancelled", "canceled":
            return "cancelled"
        case "pending", "confirmed":
            return "pending"
        default:
            return raw
        }
    }

    private var filteredLocalOrders: [PlacedOrder] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return orderStore.orders.reversed().filter { placed in
            let normalizedStatus = Self.normalizeStatus(placed.status)
            let statusMatches = selectedStatusFilter == .all || normalizedStatus == selectedStatusFilter.rawValue.lowercased()

            let matchesSearch: Bool
            if query.isEmpty {
                matchesSearch = true
            } else {
                matchesSearch =
                    placed.customer.name.lowercased().contains(query) ||
                    placed.orderNumber.lowercased().contains(query)
            }

            return statusMatches && matchesSearch
        }
    }

    private var filteredRemoteOrders: [SAOrder] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let localIds = Set(orderStore.orders.map { $0.id.uuidString.lowercased() })

        return viewModel.recentOrders
            .filter { !localIds.contains($0.id.uuidString.lowercased()) }
            .filter { order in
                let normalizedStatus = Self.normalizeStatus(order.status)
                let statusMatches = selectedStatusFilter == .all || normalizedStatus == selectedStatusFilter.rawValue.lowercased()

                let matchesSearch: Bool
                if query.isEmpty {
                    matchesSearch = true
                } else {
                    matchesSearch =
                        (order.customerName ?? "").lowercased().contains(query) ||
                        order.id.uuidString.lowercased().contains(query)
                }

                return statusMatches && matchesSearch
            }
    }

    private var hasAnyOrders: Bool {
        !(orderStore.orders.isEmpty && viewModel.recentOrders.isEmpty)
    }

    private var hasVisibleOrders: Bool {
        !(filteredLocalOrders.isEmpty && filteredRemoteOrders.isEmpty)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.luxuryBackground.ignoresSafeArea()

                if viewModel.isLoading && !hasAnyOrders {
                    LoadingView(message: "Loading orders...")
                } else if let error = viewModel.errorMessage, !hasAnyOrders {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.luxurySecondaryText)
                        Text(error)
                            .font(BrandFont.body(14))
                            .foregroundStyle(Color.luxuryPrimaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button {
                            Task { await viewModel.refresh() }
                        } label: {
                            Text("Retry")
                                .font(BrandFont.body(14, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Color.luxuryDeepAccent)
                                .clipShape(Capsule())
                        }
                    }
                } else if !hasAnyOrders {
                    EmptyStateView(icon: "shippingbox", title: "No orders", message: "Your completed and pending orders will appear here.")
                } else {
                    VStack(spacing: 0) {
                        ordersControls

                        if hasVisibleOrders {
                            ScrollView(showsIndicators: false) {
                                VStack(spacing: 10) {
                                     ForEach(filteredLocalOrders) { placed in
                                        Button {
                                            selectedOrder = placed
                                        } label: {
                                            orderRow(number: placed.orderNumber,
                                                     clientName: placed.customer.name,
                                                     amount: placed.totalAmount,
                                                     status: placed.status)
                                        }
                                        .buttonStyle(LuxuryPressStyle())
                                        .contextMenu {
                                            if placed.status.lowercased() != "completed" {
                                                Button {
                                                    Task {
                                                        await viewModel.updateOrderStatus(orderId: placed.id, status: "completed")
                                                        orderStore.updateStatus(for: placed.id, status: "completed")
                                                    }
                                                } label: {
                                                    Label("Mark Complete", systemImage: "checkmark.circle.fill")
                                                }
                                            }
                                            if placed.status.lowercased() != "cancelled" {
                                                Button(role: .destructive) {
                                                    Task {
                                                        await viewModel.updateOrderStatus(orderId: placed.id, status: "cancelled")
                                                        orderStore.updateStatus(for: placed.id, status: "cancelled")
                                                    }
                                                } label: {
                                                    Label("Cancel Order", systemImage: "xmark.circle.fill")
                                                }
                                            }
                                        }
                                    }

                                    ForEach(filteredRemoteOrders) { order in
                                        Button {
                                            selectedRemoteOrder = order
                                        } label: {
                                            orderRow(number: String(order.id.uuidString.prefix(8).uppercased()),
                                                     clientName: order.customerName ?? "–",
                                                     amount: order.totalAmount,
                                                     status: order.status ?? "pending")
                                        }
                                        .buttonStyle(LuxuryPressStyle())
                                        .contextMenu {
                                            if order.status?.lowercased() != "completed" {
                                                Button {
                                                    Task { await viewModel.updateOrderStatus(orderId: order.id, status: "completed") }
                                                } label: {
                                                    Label("Mark Complete", systemImage: "checkmark.circle.fill")
                                                }
                                            }
                                            if order.status?.lowercased() != "cancelled" {
                                                Button(role: .destructive) {
                                                    orderToCancel = order
                                                } label: {
                                                    Label("Cancel Order", systemImage: "xmark.circle.fill")
                                                }
                                            }
                                        }
                                    }
                                }
                                .padding(16)
                            }
                            .refreshable {
                                await viewModel.refresh()
                            }
                        } else {
                            EmptyStateView(
                                icon: "line.3.horizontal.decrease.circle",
                                title: "No matching orders",
                                message: "Try a different search term or status filter."
                            )
                        }
                    }
                }

                // Floating "New Order" button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button { showNewOrder = true } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .bold))
                                Text("New")
                                    .font(BrandFont.body(14, weight: .semibold))
                            }
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 13)
                            .background(Color.luxuryDeepAccent)
                            .clipShape(Capsule())
                            .shadow(color: Color.luxuryDeepAccent.opacity(0.30), radius: 10, y: 4)
                        }
                        .buttonStyle(LuxuryPressStyle())
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Orders")
            // Sheet for session-local orders (full receipt)
            .sheet(item: $selectedOrder) { order in
                StandaloneReceiptSheet(placed: order, viewModel: viewModel, onViewBilling: { billingOrderId = order.id })
            }
            // Sheet for remote orders (summary view)
            .sheet(item: $selectedRemoteOrder) { order in
                SAOrderDetailSheet(order: order, viewModel: viewModel, onViewBilling: { billingOrderId = order.id })
            }
            .sheet(isPresented: Binding(
                get: { billingOrderId != nil },
                set: { if !$0 { billingOrderId = nil } }
            )) {
                if let orderId = billingOrderId {
                    BillAndPaymentsView(vm: AssociateSalesViewModel(), salesOrderId: orderId)
                }
            }
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SalesAssociateProfileButton(sessionViewModel: sessionViewModel)
                }
            }
            .confirmationDialog(
                "Cancel Order",
                isPresented: Binding(get: { orderToCancel != nil }, set: { if !$0 { orderToCancel = nil } }),
                titleVisibility: .visible
            ) {
                Button("Cancel Order", role: .destructive) {
                    if let order = orderToCancel {
                        Task { await viewModel.updateOrderStatus(orderId: order.id, status: "cancelled") }
                    }
                    orderToCancel = nil
                }
                Button("Keep", role: .cancel) { orderToCancel = nil }
            } message: {
                Text("This will mark the order as cancelled and cannot be undone.")
            }
            .fullScreenCover(isPresented: $showNewOrder) {
                SalesAssociateSalesView(isModal: true)
                    .environmentObject(orderStore)
            }
            .task {
                await viewModel.refresh()
            }
            .onAppear {
                viewModel.objectWillChange.send()
            }
        }
    }

    private var ordersControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.luxuryPrimary)
                    .font(.system(size: 14))
                TextField("Search by client name or order ID...", text: $searchText)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.luxuryPrimaryText)
                    .autocorrectionDisabled()
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(OrderStatusFilter.allCases, id: \.self) { filter in
                        statusFilterChip(filter)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private func statusFilterChip(_ filter: OrderStatusFilter) -> some View {
        Button {
            selectedStatusFilter = filter
        } label: {
            Text(filter.rawValue)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selectedStatusFilter == filter ? Color.luxurySelection : Color.luxurySurface)
                .foregroundStyle(selectedStatusFilter == filter ? Color.white : Color.luxuryDeepAccent)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func orderRow(number: String, clientName: String, amount: Double, status: String) -> some View {
        let normalizedStatus = Self.normalizeStatus(status)
        let statusPresentation: (text: String, bgColor: Color, textColor: Color) = {
            switch normalizedStatus {
            case "completed":
                return ("Completed", Color.luxuryPrimary, Color.white)
            case "cancelled":
                return ("Cancelled", Color(hex: "#D8C6C6"), Color.luxurySecondaryText)
            case "pending":
                return ("Pending", Color(hex: "#D8C6C6"), Color.luxurySecondaryText)
            default:
                return (normalizedStatus.capitalized, Color(hex: "#D8C6C6"), Color.luxurySecondaryText)
            }
        }()

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(clientName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.luxuryPrimaryText)
                Text("Order #\(number)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.luxurySecondaryText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text(currency(amount))
                    .font(BrandFont.body(15, weight: .semibold))
                    .foregroundStyle(Color.luxuryDeepAccent)
                Text(statusPresentation.text)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(statusPresentation.textColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(statusPresentation.bgColor)
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "Rs \(formatter.string(from: NSNumber(value: value)) ?? "0")"
    }
}

// MARK: - StandaloneReceiptSheet
struct StandaloneReceiptSheet: View {
    let placed: PlacedOrder
    @ObservedObject var viewModel: SalesAssociateViewModel
    @EnvironmentObject var orderStore: SharedOrderStore
    @Environment(\.dismiss) var dismiss
    var onViewBilling: () -> Void
    @State private var isCompleting = false
    @State private var showConfirm = false
    @State private var showCancelConfirm = false

    private var normalizedStatus: String {
        SalesAssociateOrdersView.normalizeStatus(placed.status)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.luxuryBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // ── Receipt card
                        VStack(spacing: 0) {
                            BrandDivider()
                            receiptRow(label: "Customer", value: placed.customer.name)
                            BrandDivider().padding(.leading, 16)
                            if let ph = placed.customer.phone { receiptRow(label: "Phone", value: ph); BrandDivider().padding(.leading, 16) }
                            if let em = placed.customer.email { receiptRow(label: "Email", value: em); BrandDivider().padding(.leading, 16) }
                            if let cat = placed.customer.customerCategory { receiptRow(label: "Category", value: cat); BrandDivider().padding(.leading, 16) }
                            receiptRow(label: "Served by", value: placed.associateName)
                            BrandDivider()
                            ForEach(Array(placed.items.enumerated()), id: \.element.id) { index, item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.product.name).font(.system(size: 13)).foregroundStyle(Color.luxuryPrimaryText)
                                        HStack(spacing: 6) {
                                            Text("×\(item.quantity)").font(.system(size: 11)).foregroundStyle(Color.luxurySecondaryText)
                                            Text("@ ₹\(Int(item.product.price))").font(.system(size: 11)).foregroundStyle(Color.luxurySecondaryText)
                                        }
                                    }
                                    Spacer()
                                    Text("₹\(Int(item.lineTotal))").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.luxuryDeepAccent)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                if index < placed.items.count - 1 { BrandDivider().padding(.leading, 16) }
                            }
                            BrandDivider()
                            HStack {
                                Text("Total").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.luxuryPrimaryText)
                                Spacer()
                                Text("₹\(Int(placed.totalAmount))").font(.system(size: 20, weight: .semibold, design: .serif)).foregroundStyle(Color.luxuryDeepAccent)
                            }.padding(16)
                        }
                        .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        .padding(.horizontal, 16)
                        .padding(.top, 24)

                        HStack(spacing: 12) {
                            if normalizedStatus != "cancelled" {
                                Button {
                                    showCancelConfirm = true
                                } label: {
                                    HStack {
                                        Image(systemName: "xmark.circle")
                                        Text("Cancel")
                                    }
                                    .font(BrandFont.body(14, weight: .semibold))
                                    .foregroundStyle(Color(hex: "#9B4444"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#9B4444"), lineWidth: 1))
                                }
                                .buttonStyle(LuxuryPressStyle())
                                .disabled(isCompleting)
                            }

                            if normalizedStatus != "completed" {
                                Button {
                                    showConfirm = true
                                } label: {
                                    HStack(spacing: 8) {
                                        if isCompleting {
                                            ProgressView().tint(Color.white).scaleEffect(0.9)
                                        } else {
                                            Image(systemName: "checkmark.circle")
                                        }
                                        Text(isCompleting ? "Wait..." : "Complete")
                                    }
                                    .font(BrandFont.body(14, weight: .semibold))
                                    .foregroundStyle(Color.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(Color.luxuryPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                                .buttonStyle(LuxuryPressStyle())
                                .disabled(isCompleting)
                            }
                            
                            if normalizedStatus != "pending" {
                                Button {
                                    Task {
                                        isCompleting = true
                                        await viewModel.updateOrderStatus(orderId: placed.id, status: "confirmed")
                                        orderStore.updateStatus(for: placed.id, status: "confirmed")
                                        isCompleting = false
                                        if viewModel.errorMessage == nil { dismiss() }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        if isCompleting {
                                            ProgressView().tint(Color.luxuryDeepAccent).scaleEffect(0.9)
                                        } else {
                                            Image(systemName: "arrow.uturn.backward.circle")
                                        }
                                        Text("Pending")
                                    }
                                    .font(BrandFont.body(14, weight: .semibold))
                                    .foregroundStyle(Color.luxuryDeepAccent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(Color.luxurySurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                                .buttonStyle(LuxuryPressStyle())
                                .disabled(isCompleting)
                            }
                        }
                        .padding(.horizontal, 16)

                        Button {
                            onViewBilling()
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "creditcard")
                                Text("View Bill & Payments")
                            }
                            .font(BrandFont.body(14, weight: .semibold))
                            .foregroundStyle(Color.luxuryDeepAccent)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.luxurySurface)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(LuxuryPressStyle())
                        .padding(.horizontal, 16)
                        .opacity(1)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Order Confirmed").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.luxuryPrimaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .foregroundStyle(Color.luxuryPrimary)
                    .font(.system(size: 14, weight: .semibold))
                }
            }
            .alert("Complete Order", isPresented: $showConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Complete", role: .none) {
                    Task {
                        isCompleting = true
                        await viewModel.updateOrderStatus(orderId: placed.id, status: "completed")
                        orderStore.updateStatus(for: placed.id, status: "completed")
                        isCompleting = false
                        if viewModel.errorMessage == nil { dismiss() }
                    }
                }
            } message: { Text("Mark this order as completed?") }
            .alert("Cancel Order", isPresented: $showCancelConfirm) {
                Button("Keep", role: .cancel) {}
                Button("Cancel Order", role: .destructive) {
                    Task {
                        isCompleting = true
                        await viewModel.updateOrderStatus(orderId: placed.id, status: "cancelled")
                        orderStore.updateStatus(for: placed.id, status: "cancelled")
                        isCompleting = false
                        if viewModel.errorMessage == nil { dismiss() }
                    }
                }
            } message: { Text("Are you sure you want to cancel this order?") }
        }
    }

    @ViewBuilder
    private func receiptRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(Color.luxurySecondaryText)
            Spacer()
            Text(value).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.luxuryPrimaryText).multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

// MARK: - SAOrderDetailSheet
// Summary sheet for remote orders fetched from Supabase.
struct SAOrderDetailSheet: View {
    let order: SAOrder
    @ObservedObject var viewModel: SalesAssociateViewModel
    @Environment(\.dismiss) var dismiss
    var onViewBilling: () -> Void
    @State private var isCompleting = false
    @State private var showConfirm = false
    @State private var showCancelConfirm = false
    @State private var orderItems: [SALineItem] = []
    @State private var isLoadingItems = false

    struct SALineItem: Identifiable {
        let id = UUID()
        let name: String
        let category: String
        let quantity: Int
        let priceAtPurchase: Double
        var lineTotal: Double { Double(quantity) * priceAtPurchase }
    }

    private var normalizedStatus: String {
        SalesAssociateOrdersView.normalizeStatus(order.status)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.luxuryBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Status badge
                        let statusBg: Color = normalizedStatus == "completed" ? Color.luxuryPrimary : Color(hex: "#D8C6C6")
                        let statusFg: Color = normalizedStatus == "completed" ? Color.white : Color.luxurySecondaryText
                        Text(normalizedStatus.capitalized)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(statusFg)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(statusBg)
                            .clipShape(Capsule())
                            .padding(.top, 24)

                        // Detail card
                        VStack(spacing: 0) {
                            if let name = order.customerName {
                                detailRow(label: "Customer", value: name)
                                BrandDivider().padding(.leading, 16)
                            }
                            detailRow(label: "Order ID",
                                      value: "#\(String(order.id.uuidString.prefix(8)).uppercased())")
                            BrandDivider().padding(.leading, 16)
                            if let date = order.createdAt {
                                detailRow(label: "Date", value: String(date.prefix(10)))
                                BrandDivider().padding(.leading, 16)
                            }

                            // Line items
                            if isLoadingItems {
                                HStack(spacing: 8) {
                                    ProgressView().scaleEffect(0.8)
                                    Text("Loading items...")
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.luxurySecondaryText)
                                }
                                .padding(16)
                            } else if !orderItems.isEmpty {
                                BrandDivider()
                                ForEach(Array(orderItems.enumerated()), id: \.element.id) { idx, item in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.name)
                                                .font(.system(size: 13))
                                                .foregroundStyle(Color.luxuryPrimaryText)
                                            HStack(spacing: 6) {
                                                Text("×\(item.quantity)")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(Color.luxurySecondaryText)
                                                Text("@ ₹\(Int(item.priceAtPurchase))")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(Color.luxurySecondaryText)
                                            }
                                        }
                                        Spacer()
                                        Text("₹\(Int(item.lineTotal))")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Color.luxuryDeepAccent)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    if idx < orderItems.count - 1 {
                                        BrandDivider().padding(.leading, 16)
                                    }
                                }
                                BrandDivider()
                            }

                            detailRow(label: "Total",
                                      value: "₹\(Int(order.totalAmount))",
                                      valueWeight: .semibold)
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        .padding(.horizontal, 16)
                        .task { await loadOrderItems() }

                        HStack(spacing: 12) {
                            if normalizedStatus != "cancelled" {
                                Button {
                                    showCancelConfirm = true
                                } label: {
                                    HStack {
                                        Image(systemName: "xmark.circle")
                                        Text("Cancel")
                                    }
                                    .font(BrandFont.body(14, weight: .semibold))
                                    .foregroundStyle(Color(hex: "#9B4444"))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color(hex: "#9B4444"), lineWidth: 1))
                                }
                                .buttonStyle(LuxuryPressStyle())
                                .disabled(isCompleting)
                            }

                            if normalizedStatus != "completed" {
                                Button {
                                    showConfirm = true
                                } label: {
                                    HStack(spacing: 8) {
                                        if isCompleting {
                                            ProgressView().tint(Color.white).scaleEffect(0.9)
                                        } else {
                                            Image(systemName: "checkmark.circle")
                                        }
                                        Text(isCompleting ? "Wait..." : "Complete")
                                    }
                                    .font(BrandFont.body(14, weight: .semibold))
                                    .foregroundStyle(Color.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(Color.luxuryPrimary)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                                .buttonStyle(LuxuryPressStyle())
                                .disabled(isCompleting)
                            }
                            
                            if normalizedStatus != "pending" {
                                Button {
                                    Task {
                                        isCompleting = true
                                        await viewModel.updateOrderStatus(orderId: order.id, status: "confirmed")
                                        isCompleting = false
                                        if viewModel.errorMessage == nil { dismiss() }
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        if isCompleting {
                                            ProgressView().tint(Color.luxuryDeepAccent).scaleEffect(0.9)
                                        } else {
                                            Image(systemName: "arrow.uturn.backward.circle")
                                        }
                                        Text("Pending")
                                    }
                                    .font(BrandFont.body(14, weight: .semibold))
                                    .foregroundStyle(Color.luxuryDeepAccent)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .background(Color.luxurySurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                }
                                .buttonStyle(LuxuryPressStyle())
                                .disabled(isCompleting)
                            }
                        }
                        .padding(.horizontal, 16)

                        Button {
                            onViewBilling()
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "creditcard")
                                Text("View Bill & Payments")
                            }
                            .font(BrandFont.body(14, weight: .semibold))
                            .foregroundStyle(Color.luxuryDeepAccent)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.luxurySurface)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(LuxuryPressStyle())
                        .padding(.horizontal, 16)

                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Order Details")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.luxuryPrimaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .foregroundStyle(Color.luxuryPrimary)
                    .font(.system(size: 14, weight: .semibold))
                }
            }
            .alert("Complete Order", isPresented: $showConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Complete", role: .none) {
                    Task {
                        isCompleting = true
                        await viewModel.updateOrderStatus(orderId: order.id, status: "completed")
                        isCompleting = false
                        if viewModel.errorMessage == nil { dismiss() }
                    }
                }
            } message: { Text("Mark this order as completed?") }
            .alert("Cancel Order", isPresented: $showCancelConfirm) {
                Button("Keep", role: .cancel) {}
                Button("Cancel Order", role: .destructive) {
                    Task {
                        isCompleting = true
                        await viewModel.updateOrderStatus(orderId: order.id, status: "cancelled")
                        isCompleting = false
                        if viewModel.errorMessage == nil { dismiss() }
                    }
                }
            } message: { Text("Are you sure you want to cancel this order?") }
        }
    }

    @ViewBuilder
    private func detailRow(label: String, value: String, valueWeight: Font.Weight = .medium) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.luxurySecondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: valueWeight))
                .foregroundStyle(Color.luxuryPrimaryText)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }

    private func loadOrderItems() async {
        guard orderItems.isEmpty else { return }
        isLoadingItems = true
        defer { isLoadingItems = false }

        struct RawItem: Decodable {
            let quantity: Int
            let price_at_purchase: Double
            let products: ProductInfo?

            struct ProductInfo: Decodable {
                let name: String
                let category: String?
            }
        }

        do {
            let client = SupabaseManager.shared.client
            let rows: [RawItem] = try await client
                .from("order_items")
                .select("quantity, price_at_purchase, products(name, category)")
                .eq("order_id", value: order.id.uuidString)
                .execute()
                .value

            orderItems = rows.compactMap { row in
                guard let info = row.products else { return nil }
                return SALineItem(
                    name: info.name,
                    category: info.category ?? "",
                    quantity: row.quantity,
                    priceAtPurchase: row.price_at_purchase
                )
            }
        } catch {
            print("[SAOrderDetailSheet] Failed to load items: \(error)")
        }
    }
}
