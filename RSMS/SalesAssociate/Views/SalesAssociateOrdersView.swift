import SwiftUI
import Combine

struct SalesAssociateOrdersView: View {
    @StateObject private var viewModel = SalesAssociateViewModel()
    @EnvironmentObject var orderStore: SharedOrderStore
    @State private var selectedOrder: PlacedOrder? = nil
    @State private var selectedRemoteOrder: SAOrder? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandOffWhite.ignoresSafeArea()

                if viewModel.isLoading && orderStore.orders.isEmpty && viewModel.recentOrders.isEmpty {
                    LoadingView(message: "Loading orders...")
                } else if orderStore.orders.isEmpty && viewModel.recentOrders.isEmpty {
                    EmptyStateView(icon: "shippingbox", title: "No orders", message: "Your completed and pending orders will appear here.")
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            // 1. Session Local Orders (full PlacedOrder data)
                            ForEach(orderStore.orders.reversed()) { placed in
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

                            // 2. Remote Orders from Supabase (de-duplicated)
                            let localIds = Set(orderStore.orders.map { $0.id.uuidString.lowercased() })
                            ForEach(viewModel.recentOrders.filter { !localIds.contains($0.id.uuidString.lowercased()) }) { order in
                                Button {
                                    selectedRemoteOrder = order
                                } label: {
                                    orderRow(number: String(order.id.uuidString.prefix(8).uppercased()),
                                             clientName: order.customerName ?? "–",
                                             amount: order.totalAmount,
                                             status: order.status ?? "–")
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                    .refreshable {
                        await viewModel.refresh()
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
                SAOrderDetailSheet(order: order)
            }
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.refresh()
            }
            .onAppear {
                viewModel.objectWillChange.send()
            }
        }
    }

    @ViewBuilder
    private func orderRow(number: String, clientName: String, amount: Double, status: String) -> some View {
        HStack {
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
                Text(status.capitalized)
                    .font(BrandFont.body(11))
                    .foregroundStyle(Color(hex: "#C8913A"))
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
    @Environment(\.dismiss) var dismiss

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
                            Text((order.status ?? "–").capitalized)
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
