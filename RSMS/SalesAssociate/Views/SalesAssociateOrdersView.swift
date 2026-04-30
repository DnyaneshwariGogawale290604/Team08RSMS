import SwiftUI
import Combine
import Supabase
import PostgREST

struct SalesAssociateOrdersView: View {
    @ObservedObject private var sessionViewModel: SessionViewModel
    private enum OrderStatusFilter: String, CaseIterable {
        case active = "Active"
        case completed = "Completed"
        case cancelled = "Cancelled"
    }

    @StateObject private var viewModel = SalesAssociateViewModel()
    @EnvironmentObject var orderStore: SharedOrderStore
    @State private var selectedOrder: PlacedOrder? = nil
    @State private var selectedRemoteOrder: SAOrder? = nil
    @State private var searchText = ""
    @State private var selectedStatusFilter: OrderStatusFilter = .active
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
        case "pending":
            return "pending"
        case "confirmed":
            return "confirmed"
        default:
            return raw
        }
    }

    fileprivate static func statusPresentation(_ normalizedStatus: String, shippingStatus: String? = nil) -> (text: String, bgColor: Color, textColor: Color) {
        let normalizedShipping = (shippingStatus ?? "").lowercased()

        if normalizedStatus == "returned" || normalizedShipping == "returned" {
            return ("Returned", Color(hex: "#9B4444").opacity(0.1), Color(hex: "#9B4444"))
        } else if normalizedStatus == "cancelled" {
            return ("Cancelled", Color(hex: "#D8C6C6"), Color.luxurySecondaryText)
        } else if normalizedStatus == "completed" || normalizedShipping == "delivered" {
            return ("Delivered", Color.green.opacity(0.1), Color.green)
        } else if normalizedShipping == "out_for_delivery" {
            return ("Out for Delivery", Color.orange.opacity(0.1), Color.orange)
        } else if normalizedShipping == "in_transit" {
            return ("In Transit", Color.purple.opacity(0.1), Color.purple)
        } else if normalizedShipping == "accepted" || normalizedShipping == "picked_up" {
            return ("Picked Up", Color.blue.opacity(0.1), Color.blue)
        } else if normalizedStatus == "confirmed" {
            return ("Confirmed", Color.luxuryPrimary.opacity(0.1), Color.luxuryPrimary)
        } else {
            return ("Pending", Color(hex: "#D8C6C6"), Color.luxurySecondaryText)
        }
    }

    private func filterMatchesStatus(_ normalizedStatus: String, filter: OrderStatusFilter) -> Bool {
        switch filter {
        case .active:
            return ["open", "pending", "confirmed", "returned"].contains(normalizedStatus)
        case .completed:
            return normalizedStatus == "completed"
        case .cancelled:
            return normalizedStatus == "cancelled"
        }
    }

    private var filteredLocalOrders: [PlacedOrder] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let remoteIds = Set(viewModel.recentOrders.map { $0.id.uuidString.lowercased() })

        return orderStore.orders.reversed()
            .filter { !remoteIds.contains($0.id.uuidString.lowercased()) }
            .filter { placed in
                let normalizedStatus = Self.normalizeStatus(placed.status)
                let statusMatches = filterMatchesStatus(normalizedStatus, filter: selectedStatusFilter)

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

        return viewModel.recentOrders
            .filter { order in
                let normalizedStatus = Self.normalizeStatus(order.status)
                let statusMatches = filterMatchesStatus(normalizedStatus, filter: selectedStatusFilter)

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
                                        OrderListItem(
                                            number: placed.orderNumber,
                                            clientName: placed.customer.name,
                                            amount: placed.totalAmount,
                                            status: placed.status,
                                            shippingStatus: placed.shippingStatus,
                                            onTap: { selectedOrder = placed },
                                            onCancel: {
                                                Task {
                                                    await viewModel.updateOrderStatus(orderId: placed.id, status: "cancelled")
                                                    orderStore.updateStatus(for: placed.id, status: "cancelled")
                                                }
                                            }
                                        )
                                    }

                                    ForEach(filteredRemoteOrders) { order in
                                        OrderListItem(
                                            number: String(order.id.uuidString.prefix(8).uppercased()),
                                            clientName: order.customerName ?? "–",
                                            amount: order.totalAmount,
                                            status: order.status ?? "pending",
                                            shippingStatus: order.shippingStatus,
                                            onTap: { selectedRemoteOrder = order },
                                            onCancel: { orderToCancel = order }
                                        )
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
            .navigationBarTitleDisplayMode(.inline)
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
            .background(Color.luxurySurface)
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
                .background(selectedStatusFilter == filter ? Color.luxuryPrimary : Color.luxurySurface)
                .foregroundStyle(selectedStatusFilter == filter ? Color.white : Color.luxuryDeepAccent)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func orderRow(number: String, clientName: String, amount: Double, status: String, shippingStatus: String?) -> some View {
        let normalizedStatus = Self.normalizeStatus(status)
        let presentation = Self.statusPresentation(normalizedStatus, shippingStatus: shippingStatus)

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
                Text(presentation.text)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(presentation.textColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(presentation.bgColor)
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
    
    @StateObject private var shippingVM = CustomerShippingViewModel()
    @State private var showShipConfirm = false

    @State private var showTracking = false
    
    private var normalizedStatus: String {
        SalesAssociateOrdersView.normalizeStatus(placed.status)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.luxuryBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        receiptCard
                        
                        // ── FULFILLMENT SECTION ──
                        let shipStatus = (placed.shippingStatus ?? "").lowercased()
                        if normalizedStatus == "confirmed" {
                            if shipStatus == "pending_fulfillment" || shipStatus.isEmpty {
                                fulfillmentSection
                            } else {
                                Button {
                                    showTracking = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "location.fill")
                                        Text(shipStatus == "delivered" || normalizedStatus == "completed" ? "View Delivery Details" : "Track Shipment")
                                    }
                                    .font(BrandFont.body(14, weight: .bold))
                                    .padding(.vertical, 14)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white)
                                    .foregroundStyle(BoutiqueTheme.deepAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(BoutiqueTheme.deepAccent, lineWidth: 1))
                                }
                                .buttonStyle(LuxuryPressStyle())
                                .padding(.horizontal, 16)
                            }
                        }

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


                            if normalizedStatus == "pending" || normalizedStatus == "open" {
                                Button {
                                    Task {
                                        isCompleting = true
                                        await viewModel.updateOrderStatus(orderId: placed.id, status: "confirmed")
                                        orderStore.updateStatus(for: placed.id, status: "confirmed")
                                        isCompleting = false
                                        // No dismiss here — allow associate to ship immediately
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        if isCompleting {
                                            ProgressView().tint(Color.luxuryDeepAccent).scaleEffect(0.9)
                                        } else {
                                            Image(systemName: "checkmark.seal")
                                        }
                                        Text("Confirm Order")
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
                            HStack(spacing: 12) {
                                Image(systemName: "creditcard.fill")
                                    .font(.system(size: 16))
                                Text("View Bill & Payments")
                                    .kerning(0.5)
                            }
                            .font(BrandFont.body(14, weight: .bold))
                            .foregroundStyle(Color.luxuryDeepAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.luxurySurface)
                                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.luxuryDeepAccent.opacity(0.15), lineWidth: 1)
                            )
                        }
                        .buttonStyle(LuxuryPressStyle())
                        .padding(.horizontal, 16)
                        .opacity(1)
                        
                        if normalizedStatus == "completed" {
                            Button {
                                // Simulate receipt download
                                isCompleting = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    isCompleting = false
                                }
                            } label: {
                                HStack {
                                    if isCompleting {
                                        ProgressView().tint(Color.luxuryDeepAccent).scaleEffect(0.9)
                                    } else {
                                        Image(systemName: "square.and.arrow.down")
                                    }
                                    Text(isCompleting ? "Downloading..." : "Download Receipt")
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
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showTracking) {
                ShipmentTrackingSheet(orderId: placed.id, shippingStatus: placed.shippingStatus ?? "", shippingViewModel: shippingVM)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ORDER CONFIRMED").font(.system(size: 13, weight: .semibold)).kerning(2).foregroundStyle(Color.luxuryPrimaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }.foregroundStyle(Color.luxuryPrimary).font(.system(size: 14, weight: .semibold))
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
            .alert("Add to Transit?", isPresented: $showShipConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Confirm") {
                    print("[Fulfillment] Confirming transit for \(placed.id)")
                    Task {
                        if let brandId = try? await viewModel.fetchBrandId() {
                            print("[Fulfillment] Using brandId: \(brandId)")
                            await shippingVM.bookShipment(orderId: placed.id, brandId: brandId)
                            if shippingVM.bookingSuccess {
                                await viewModel.refresh()
                            }
                        } else {
                            print("[Fulfillment] Failed to resolve brandId")
                        }
                    }
                }
            } message: {
                Text("This will move the order to the transit phase. The courier will be assigned automatically.")
            }
        }
    }

    private var receiptCard: some View {
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
            
            if normalizedStatus == "cancelled" {
                BrandDivider()
                VStack(alignment: .leading, spacing: 8) {
                    receiptRow(label: "Cancellation Reason", value: "Customer Request")
                    receiptRow(label: "Refund Status", value: "Processed Locally")
                }
                .background(Color(hex: "#D8C6C6").opacity(0.1))
            }
        }
        .background(Color.white).clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal, 16)
        .padding(.top, 24)
    }

    private var fulfillmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("FULFILLMENT")
                .font(.system(size: 11, weight: .semibold))
                .kerning(1.2)
                .foregroundStyle(Color.luxurySecondaryText)
                .padding(.horizontal, 4)

            if shippingVM.bookingSuccess {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                    Text("Added to Transit — AWB: \(shippingVM.lastAWB ?? "")")
                        .font(BrandFont.body(14, weight: .semibold))
                        .foregroundStyle(Color.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                VStack(spacing: 12) {
                    if shippingVM.isBooking {
                        VStack(spacing: 8) {
                            ProgressView()
                                .tint(Color.luxuryDeepAccent)
                            Text("Booking shipment...")
                                .font(BrandFont.body(13))
                                .foregroundStyle(Color.luxurySecondaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        Button {
                            showShipConfirm = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "truck.box.fill")
                                    .font(.system(size: 16))
                                Text("Add to Transit")
                                    .font(BrandFont.body(15, weight: .bold))
                            }
                            .foregroundStyle(Color.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.luxuryDeepAccent)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.luxuryDeepAccent.opacity(0.3), radius: 8, y: 4)
                        }
                        .buttonStyle(LuxuryPressStyle())
                    }

                    if let err = shippingVM.bookingError {
                        VStack(spacing: 8) {
                            Text(err)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.red)
                                .multilineTextAlignment(.center)
                            
                            Button {
                                Task {
                                    if let brandId = try? await viewModel.fetchBrandId() {
                                        await shippingVM.bookShipment(orderId: placed.id, brandId: brandId)
                                        if shippingVM.bookingSuccess {
                                            await viewModel.refresh()
                                        }
                                    }
                                }
                            } label: {
                                Text("Retry Booking")
                                    .font(BrandFont.body(12, weight: .semibold))
                                    .foregroundStyle(Color.luxuryDeepAccent)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color.luxurySurface)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(Color.luxuryDeepAccent, lineWidth: 0.5))
                            }
                        }
                        .padding(.top, 4)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
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
    @StateObject private var shippingVM = CustomerShippingViewModel()
    @State private var showCancelConfirm = false
    @State private var showShipConfirm = false
    @State private var showTracking = false
    @State private var orderItems: [SALineItem] = []
    @State private var isLoadingItems = false

    struct SALineItem: Identifiable {
        let id = UUID()
        let name: String
        let category: String
        let quantity: Int
        let priceAtPurchase: Double
        let status: String?
        var lineTotal: Double { Double(quantity) * priceAtPurchase }
    }

    private var currentOrder: SAOrder {
        viewModel.recentOrders.first(where: { $0.id == order.id }) ?? order
    }

    private var normalizedStatus: String {
        SalesAssociateOrdersView.normalizeStatus(currentOrder.status)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.luxuryBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Status badge
                        let normalizedShipping = (currentOrder.shippingStatus ?? "").lowercased()
                        let statusBg: Color = {
                            if normalizedStatus == "returned" || normalizedShipping == "returned" { return Color(hex: "#9B4444").opacity(0.1) }
                            if normalizedStatus == "completed" || normalizedShipping == "delivered" { return Color.green.opacity(0.1) }
                            if normalizedShipping == "out_for_delivery" { return Color.orange.opacity(0.1) }
                            if normalizedShipping == "in_transit" { return Color.purple.opacity(0.1) }
                            if normalizedShipping == "accepted" || normalizedShipping == "picked_up" { return Color.blue.opacity(0.1) }
                            return Color(hex: "#D8C6C6")
                        }()
                        let statusFg: Color = {
                            if normalizedStatus == "returned" || normalizedShipping == "returned" { return Color(hex: "#9B4444") }
                            if normalizedStatus == "completed" || normalizedShipping == "delivered" { return Color.green }
                            if normalizedShipping == "out_for_delivery" { return Color.orange }
                            if normalizedShipping == "in_transit" { return Color.purple }
                            if normalizedShipping == "accepted" || normalizedShipping == "picked_up" { return Color.blue }
                            return Color.luxurySecondaryText
                        }()
                        Text((normalizedShipping != "" && normalizedShipping != "pending_fulfillment") ? normalizedShipping.replacingOccurrences(of: "_", with: " ").capitalized : normalizedStatus.capitalized)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(statusFg)
                            .padding(.horizontal, 14).padding(.vertical, 6)
                            .background(statusBg)
                            .clipShape(Capsule())
                            .padding(.top, 24)
                        
                        if normalizedStatus == "returned" || normalizedShipping == "returned" {
                            HStack {
                                Image(systemName: "arrow.uturn.left.circle.fill")
                                Text("Return in Progress")
                                    .font(BrandFont.body(13, weight: .semibold))
                                Spacer()
                            }
                            .padding()
                            .foregroundStyle(Color.white)
                            .background(Color(hex: "#9B4444"))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding(.horizontal, 16)
                        }

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
                                            HStack(spacing: 6) {
                                                if item.status == "returned" {
                                                    Text("Returned")
                                                        .font(.system(size: 10, weight: .bold))
                                                        .foregroundStyle(Color(hex: "#9B4444"))
                                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                                        .background(Color(hex: "#9B4444").opacity(0.1))
                                                        .clipShape(Capsule())
                                                }
                                                Text(item.name)
                                                    .font(.system(size: 13))
                                                    .foregroundStyle(item.status == "returned" ? Color.luxurySecondaryText : Color.luxuryPrimaryText)
                                                    .strikethrough(item.status == "returned", color: Color.luxurySecondaryText)
                                            }
                                            HStack(spacing: 6) {
                                                Text("×\(item.quantity)")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(Color.luxurySecondaryText)
                                                    .strikethrough(item.status == "returned", color: Color.luxurySecondaryText)
                                                Text("@ ₹\(Int(item.priceAtPurchase))")
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(Color.luxurySecondaryText)
                                                    .strikethrough(item.status == "returned", color: Color.luxurySecondaryText)
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
                            if order.amountPaid > 0 {
                                BrandDivider().padding(.leading, 16)
                                HStack {
                                    Text("Paid")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.luxurySecondaryText)
                                    Spacer()
                                    Text("₹\(Int(order.amountPaid))")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(Color.luxuryPrimary)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                                BrandDivider().padding(.leading, 16)
                                HStack {
                                    Text("Due")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(order.dueAmount > 0
                                            ? Color(hex: "#9B4444")
                                            : Color.luxurySecondaryText)
                                    Spacer()
                                    Text(order.dueAmount > 0 ? "₹\(Int(order.dueAmount))" : "Fully Paid")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(order.dueAmount > 0
                                            ? Color(hex: "#9B4444")
                                            : Color.luxuryPrimary)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 14)
                            }
                            
                            if normalizedStatus == "cancelled" {
                                BrandDivider()
                                VStack(alignment: .leading, spacing: 8) {
                                    detailRow(label: "Cancellation Reason", value: "Customer Request")
                                    detailRow(label: "Refund Status", value: order.amountPaid > 0 ? "Refunded to Original Source" : "No Payment Processed")
                                }
                                .background(Color(hex: "#D8C6C6").opacity(0.1))
                            }
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                        .padding(.horizontal, 16)
                        .task { await loadOrderItems() }

                        // ── FULFILLMENT SECTION ──
                        let shipStatus = (currentOrder.shippingStatus ?? "").lowercased()
                        if normalizedStatus == "confirmed" {
                            if shipStatus == "pending_fulfillment" || shipStatus.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("FULFILLMENT")
                                        .font(.system(size: 11, weight: .semibold))
                                        .kerning(1.2)
                                        .foregroundStyle(BoutiqueTheme.secondaryText)
                                        .padding(.horizontal, 4)

                                    if shippingVM.bookingSuccess {
                                        VStack(spacing: 12) {
                                            HStack(spacing: 8) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundStyle(Color.green)
                                                Text("Shipment booked — AWB: \(shippingVM.lastAWB ?? "")")
                                                    .font(BrandFont.body(14, weight: .semibold))
                                                    .foregroundStyle(Color.green)
                                            }
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 16)
                                            .background(Color.green.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                            
                                            Button {
                                                showTracking = true
                                            } label: {
                                                HStack(spacing: 8) {
                                                    Image(systemName: "location.fill")
                                                    Text("Track Shipment")
                                                }
                                                .font(BrandFont.body(14, weight: .bold))
                                                .padding(.vertical, 14)
                                                .frame(maxWidth: .infinity)
                                                .background(Color.white)
                                                .foregroundStyle(BoutiqueTheme.deepAccent)
                                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(BoutiqueTheme.deepAccent, lineWidth: 1))
                                            }
                                            .buttonStyle(LuxuryPressStyle())
                                        }
                                    } else {
                                        VStack(spacing: 12) {
                                            if shippingVM.isBooking {
                                                VStack(spacing: 8) {
                                                    ProgressView()
                                                        .tint(BoutiqueTheme.deepAccent)
                                                    Text("Booking shipment...")
                                                        .font(BrandFont.body(13))
                                                        .foregroundStyle(BoutiqueTheme.secondaryText)
                                                }
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 20)
                                            } else {
                                                Button {
                                                    showShipConfirm = true
                                                } label: {
                                                    HStack(spacing: 10) {
                                                        Image(systemName: "truck.box.fill")
                                                            .font(.system(size: 16))
                                                        Text("Add to Transit")
                                                            .font(BrandFont.body(15, weight: .bold))
                                                    }
                                                    .foregroundStyle(Color.white)
                                                    .frame(maxWidth: .infinity)
                                                    .padding(.vertical, 14)
                                                    .background(BoutiqueTheme.deepAccent)
                                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                                    .shadow(color: BoutiqueTheme.deepAccent.opacity(0.3), radius: 8, y: 4)
                                                }
                                                .buttonStyle(LuxuryPressStyle())
                                            }

                                            if let err = shippingVM.bookingError {
                                                VStack(spacing: 8) {
                                                    Text(err)
                                                        .font(.system(size: 12))
                                                        .foregroundStyle(Color.red)
                                                        .multilineTextAlignment(.center)
                                                    
                                                    Button {
                                                        Task {
                                                            if let brandId = try? await viewModel.fetchBrandId() {
                                                                await shippingVM.bookShipment(orderId: order.id, brandId: brandId)
                                                                if shippingVM.bookingSuccess {
                                                                    await viewModel.refresh()
                                                                }
                                                            }
                                                        }
                                                    } label: {
                                                        Text("Retry Booking")
                                                            .font(BrandFont.body(12, weight: .semibold))
                                                            .foregroundStyle(BoutiqueTheme.deepAccent)
                                                            .padding(.horizontal, 12)
                                                            .padding(.vertical, 6)
                                                            .background(BoutiqueTheme.surface)
                                                            .clipShape(Capsule())
                                                            .overlay(Capsule().stroke(BoutiqueTheme.deepAccent, lineWidth: 0.5))
                                                    }
                                                }
                                                .padding(.top, 4)
                                            }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            } else {
                                Button {
                                    showTracking = true
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: "location.fill")
                                        Text(shipStatus == "delivered" || normalizedStatus == "completed" ? "View Delivery Details" : "Track Shipment")
                                    }
                                    .font(BrandFont.body(14, weight: .bold))
                                    .padding(.vertical, 14)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white)
                                    .foregroundStyle(BoutiqueTheme.deepAccent)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(BoutiqueTheme.deepAccent, lineWidth: 1))
                                }
                                .buttonStyle(LuxuryPressStyle())
                                .padding(.horizontal, 16)
                            }
                        }

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


                            if normalizedStatus == "pending" || normalizedStatus == "open" {
                                Button {
                                    Task {
                                        isCompleting = true
                                        await viewModel.updateOrderStatus(orderId: order.id, status: "confirmed")
                                        isCompleting = false
                                        // No dismiss here — allow associate to ship immediately
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        if isCompleting {
                                            ProgressView().tint(Color.luxuryDeepAccent).scaleEffect(0.9)
                                        } else {
                                            Image(systemName: "checkmark.seal")
                                        }
                                        Text("Confirm Order")
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
                        
                        if normalizedStatus == "completed" {
                            Button {
                                // Simulate receipt download
                                isCompleting = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                    isCompleting = false
                                }
                            } label: {
                                HStack {
                                    if isCompleting {
                                        ProgressView().tint(Color.luxuryDeepAccent).scaleEffect(0.9)
                                    } else {
                                        Image(systemName: "square.and.arrow.down")
                                    }
                                    Text(isCompleting ? "Downloading..." : "Download Receipt")
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
                            .padding(.horizontal, 16)
                        }
                        Button {
                            onViewBilling()
                            dismiss()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "creditcard.fill")
                                    .font(.system(size: 16))
                                Text("View Bill & Payments")
                                    .kerning(0.5)
                            }
                            .font(BrandFont.body(14, weight: .bold))
                            .foregroundStyle(Color.luxuryDeepAccent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.luxurySurface)
                                    .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.luxuryDeepAccent.opacity(0.15), lineWidth: 1)
                            )
                        }
                        .buttonStyle(LuxuryPressStyle())
                        .padding(.horizontal, 16)

                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showTracking) {
                ShipmentTrackingSheet(orderId: order.id, shippingStatus: order.shippingStatus ?? "", shippingViewModel: shippingVM)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ORDER DETAILS")
                        .font(.system(size: 13, weight: .semibold))
                        .kerning(2)
                        .foregroundStyle(Color.luxuryPrimaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
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
            .alert("Add to Transit?", isPresented: $showShipConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Confirm") {
                    print("[Fulfillment] SAOrderDetailSheet: Confirming transit for \(order.id)")
                    Task {
                        if let brandId = try? await viewModel.fetchBrandId() {
                            print("[Fulfillment] SAOrderDetailSheet: Using brandId: \(brandId)")
                            await shippingVM.bookShipment(orderId: order.id, brandId: brandId)
                            if shippingVM.bookingSuccess {
                                await viewModel.refresh()
                            }
                        } else {
                            print("[Fulfillment] SAOrderDetailSheet: Failed to resolve brandId")
                        }
                    }
                }
            } message: {
                Text("This will move the order to the transit phase. The courier will be assigned automatically.")
            }
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
            let status: String?
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
                .select("quantity, price_at_purchase, status, products(name, category)")
                .eq("order_id", value: order.id.uuidString)
                .execute()
                .value

            orderItems = rows.compactMap { row in
                guard let info = row.products else { return nil }
                return SALineItem(
                    name: info.name,
                    category: info.category ?? "",
                    quantity: row.quantity,
                    priceAtPurchase: row.price_at_purchase,
                    status: row.status
                )
            }
        } catch {
            print("[SAOrderDetailSheet] Failed to load items: \(error)")
        }
    }
}

// MARK: - OrderListItem
struct OrderListItem: View {
    let number: String
    let clientName: String
    let amount: Double
    let status: String
    let shippingStatus: String?
    let onTap: () -> Void
    let onCancel: () -> Void

    var body: some View {
        Button(action: onTap) {
            orderRow(number: number,
                     clientName: clientName,
                     amount: amount,
                     status: status,
                     shippingStatus: shippingStatus)
        }
        .buttonStyle(LuxuryPressStyle())
        .contextMenu {
            if status.lowercased() != "cancelled" {
                Button(role: .destructive, action: onCancel) {
                    Label("Cancel Order", systemImage: "xmark.circle.fill")
                }
            }
        }
    }

    private func orderRow(number: String, clientName: String, amount: Double, status: String, shippingStatus: String?) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("#\(number)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.luxuryPrimaryText)
                    
                    if let shipStatus = shippingStatus {
                        shippingBadge(shipStatus)
                    }
                }
                
                Text(clientName)
                    .font(BrandFont.body(15, weight: .medium))
                    .foregroundStyle(Color.luxurySecondaryText)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 6) {
                Text("₹\(Int(amount))")
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundStyle(Color.luxuryDeepAccent)
                
                statusBadge(status)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.03), radius: 4, y: 2)
    }

    private func statusBadge(_ status: String) -> some View {
        let normalizedStatus = SalesAssociateOrdersView.normalizeStatus(status)
        let (text, bgColor, textColor) = SalesAssociateOrdersView.statusPresentation(normalizedStatus, shippingStatus: shippingStatus)
        
        return Text(text.uppercased())
            .font(.system(size: 9, weight: .bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(bgColor)
            .foregroundStyle(textColor)
            .clipShape(Capsule())
    }

    private func shippingBadge(_ status: String) -> some View {
        let text: String
        let color: Color
        
        switch status.lowercased() {
        case "pending_fulfillment":
            text = "Pending Ship"
            color = Color.orange
        case "accepted":
            text = "Accepted"
            color = Color.blue
        case "in_transit":
            text = "In Transit"
            color = Color.purple
        case "delivered":
            text = "Delivered"
            color = Color.green
        case "returned":
            text = "Returned"
            color = Color.red
        default:
            text = status.replacingOccurrences(of: "_", with: " ").capitalized
            color = Color.gray
        }
        
        return HStack(spacing: 4) {
            Circle().fill(color).frame(width: 5, height: 5)
            Text(text.uppercased())
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}
