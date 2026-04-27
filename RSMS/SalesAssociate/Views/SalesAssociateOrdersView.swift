import SwiftUI
import Combine

struct SalesAssociateOrdersView: View {
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
    @State private var showNewSale = false
    @State private var searchText = ""
    @State private var selectedStatusFilter: OrderStatusFilter = .all

    fileprivate static func normalizeStatus(_ rawStatus: String?) -> String {
        let raw = (rawStatus ?? "pending").trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if raw.isEmpty { return "pending" }

        switch raw {
        case "complete", "completed":
            return "completed"
        case "cancelled", "canceled":
            return "cancelled"
        case "pending":
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
                Color.brandOffWhite.ignoresSafeArea()

                if viewModel.isLoading && !hasAnyOrders {
                    LoadingView(message: "Loading orders...")
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
                                        .buttonStyle(.plain)
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
                                        .buttonStyle(.plain)
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
            }
            .navigationTitle("Orders")
            // Sheet for session-local orders (full receipt)
            .sheet(item: $selectedOrder) { order in
                StandaloneReceiptSheet(placed: order)
            }
            // Sheet for remote orders (summary view)
            .sheet(item: $selectedRemoteOrder) { order in
                SAOrderDetailSheet(order: order, viewModel: viewModel)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewSale = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.brandWarmBlack)
                    }
                }
            }
            .fullScreenCover(isPresented: $showNewSale) {
                SalesAssociateSalesView(isModal: true) {
                    showNewSale = false
                    Task {
                        await viewModel.refresh()
                    }
                }
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
                    .foregroundStyle(Color.brandWarmGrey)
                    .font(.system(size: 14))
                TextField("Search by client name or order ID...", text: $searchText)
                    .font(.system(size: 14))
                    .autocorrectionDisabled()
            }
            .padding(14)
            .background(Color.brandLinen)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandPebble, lineWidth: 0.5))

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
                .background(selectedStatusFilter == filter ? Color.brandWarmBlack : Color.brandLinen)
                .foregroundStyle(selectedStatusFilter == filter ? Color.brandOffWhite : Color.brandWarmBlack)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.brandPebble, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func orderRow(number: String, clientName: String, amount: Double, status: String) -> some View {
        let normalizedStatus = Self.normalizeStatus(status)
        let statusPresentation: (text: String, color: Color) = {
            switch normalizedStatus {
            case "completed":
                return ("Completed", Color.brandWarmBlack)
            case "cancelled":
                return ("Cancelled", Color.brandWarmGrey)
            case "pending":
                return ("Pending", Color(hex: "#C8913A"))
            default:
                return (normalizedStatus.capitalized, Color.brandWarmGrey)
            }
        }()

        return HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(clientName)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.brandWarmBlack)
                Text("Order #\(number)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.brandWarmBlack)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(currency(amount))
                    .font(BrandFont.body(14, weight: .semibold))
                    .foregroundStyle(Color.brandWarmBlack)
                Text(statusPresentation.text)
                    .font(BrandFont.body(11))
                    .foregroundStyle(statusPresentation.color)
            }
        }
        .padding(14)
        .background(Color.brandLinen)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brandPebble, lineWidth: 0.5))
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
    @Environment(\ .dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandOffWhite.ignoresSafeArea()
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
                                        Text(item.product.name).font(.system(size: 13)).foregroundStyle(Color.brandWarmBlack)
                                        HStack(spacing: 6) {
                                            Text("×\(item.quantity)").font(.system(size: 11)).foregroundStyle(Color.brandWarmGrey)
                                            Text("@ ₹\(Int(item.product.price))").font(.system(size: 11)).foregroundStyle(Color.brandWarmGrey)
                                        }
                                    }
                                    Spacer()
                                    Text("₹\(Int(item.lineTotal))").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.brandWarmBlack)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                if index < placed.items.count - 1 { BrandDivider().padding(.leading, 16) }
                            }
                            BrandDivider()
                            HStack {
                                Text("Total").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.brandWarmBlack)
                                Spacer()
                                Text("₹\(Int(placed.totalAmount))").font(.system(size: 20, weight: .semibold, design: .serif)).foregroundStyle(Color.brandWarmBlack)
                            }.padding(16)
                        }
                        .background(Color.brandLinen).clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandPebble, lineWidth: 0.5))
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ORDER CONFIRMED").font(.system(size: 13, weight: .semibold)).kerning(2).foregroundStyle(Color.brandWarmBlack)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }.foregroundStyle(Color.brandWarmBlack).font(.system(size: 14, weight: .semibold))
                }
            }
        }
    }

    @ViewBuilder
    private func receiptRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 13)).foregroundStyle(Color.brandWarmGrey)
            Spacer()
            Text(value).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.brandWarmBlack).multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }
}

// MARK: - SAOrderDetailSheet
// Summary sheet for remote orders fetched from Supabase.
// SAOrder only carries order-level data (no line items), so we show what's available.
struct SAOrderDetailSheet: View {
    let order: SAOrder
    @ObservedObject var viewModel: SalesAssociateViewModel
    @Environment(\.dismiss) var dismiss
    @State private var isCompleting = false
    @State private var showConfirm = false

    private var normalizedStatus: String {
        SalesAssociateOrdersView.normalizeStatus(order.status)
    }

    private var canComplete: Bool {
        normalizedStatus == "pending"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandOffWhite.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Status badge
                        HStack(spacing: 6) {
                            Circle()
                                .fill(Color(hex: "#C8913A"))
                                .frame(width: 6, height: 6)
                            Text(normalizedStatus.capitalized)
                                .font(BrandFont.body(12, weight: .medium))
                                .foregroundStyle(Color(hex: "#C8913A"))
                        }
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(Color(hex: "#C8913A").opacity(0.1))
                        .clipShape(Capsule())
                        .padding(.top, 24)

                        // Detail card
                        VStack(spacing: 0) {
                            detailRow(label: "Order ID",
                                      value: "#\(String(order.id.uuidString.prefix(8)).uppercased())")
                            BrandDivider().padding(.leading, 16)
                            detailRow(label: "Date", value: order.createdAt ?? "–")
                            BrandDivider().padding(.leading, 16)
                            detailRow(label: "Total",
                                      value: "₹\(Int(order.totalAmount))",
                                      valueWeight: .semibold)
                        }
                        .background(Color.brandLinen)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandPebble, lineWidth: 0.5))
                        .padding(.horizontal, 16)

                        if canComplete {
                            Button {
                                showConfirm = true
                            } label: {
                                HStack(spacing: 8) {
                                    if isCompleting {
                                        ProgressView()
                                            .tint(Color.brandOffWhite)
                                            .scaleEffect(0.9)
                                    } else {
                                        Image(systemName: "checkmark.circle")
                                            .font(.system(size: 14, weight: .semibold))
                                    }

                                    Text(isCompleting ? "Completing..." : "Mark as Completed")
                                        .font(BrandFont.body(14, weight: .semibold))
                                }
                                .foregroundStyle(Color.brandOffWhite)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 13)
                                .background(Color.brandWarmBlack)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .buttonStyle(.plain)
                            .disabled(isCompleting)
                            .padding(.horizontal, 16)
                        }

                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ORDER DETAILS")
                        .font(.system(size: 13, weight: .semibold))
                        .kerning(2)
                        .foregroundStyle(Color.brandWarmBlack)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(Color.brandWarmBlack)
                        .font(.system(size: 14, weight: .semibold))
                }
            }
            .alert("Complete Order", isPresented: $showConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Complete", role: .none) {
                    Task {
                        isCompleting = true
                        await viewModel.completeOrder(orderId: order.id)
                        isCompleting = false
                        if viewModel.errorMessage == nil {
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("Mark this order as completed?")
            }
        }
    }

    @ViewBuilder
    private func detailRow(label: String, value: String, valueWeight: Font.Weight = .medium) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.brandWarmGrey)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: valueWeight))
                .foregroundStyle(Color.brandWarmBlack)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16).padding(.vertical, 14)
    }
}
