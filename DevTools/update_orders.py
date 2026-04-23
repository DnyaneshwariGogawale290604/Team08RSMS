import re

code = open("SalesAssociate/Views/SalesAssociateOrdersView.swift").read()

# Instead of viewModel.recentOrders, let's use orderStore.orders
code = code.replace("@StateObject private var viewModel = SalesAssociateViewModel()", "@StateObject private var viewModel = SalesAssociateViewModel()\n    @EnvironmentObject var orderStore: SharedOrderStore\n    @State private var selectedOrder: PlacedOrder? = nil")

code = code.replace("if viewModel.isLoading && viewModel.recentOrders.isEmpty {", "if viewModel.isLoading && orderStore.orders.isEmpty && viewModel.recentOrders.isEmpty {")

# Replace the ForEach block
# The original code loops over SAOrder: ForEach(viewModel.recentOrders) { order in ...
# Let's change it to loop over orderStore.orders
old_list = """                    } else if viewModel.recentOrders.isEmpty {
                        EmptyStateView(icon: "shippingbox", title: "No orders", message: "Your completed and pending orders will appear here.")
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 10) {
                                ForEach(viewModel.recentOrders) { order in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Order #\(order.id.uuidString.prefix(8).uppercased())")
                                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                                .foregroundStyle(Color.brandWarmBlack)
                                            Text(order.createdAt ?? "")
                                                .font(BrandFont.body(11))
                                                .foregroundStyle(Color.brandWarmGrey)
                                        }
                                        Spacer()
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text(currency(order.totalAmount))
                                                .font(BrandFont.body(14, weight: .semibold))
                                                .foregroundStyle(Color.brandWarmBlack)
                                            Text((order.status ?? "pending").capitalized)
                                                .font(BrandFont.body(11))
                                                .foregroundStyle(Color.brandWarmGrey)
                                        }
                                    }
                                    .padding(14)
                                    .background(Color.brandLinen)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(Color.brandPebble, lineWidth: 0.5)
                                    )
                                }
                            }
                            .padding(16)
                        }
                        .refreshable {
                            await viewModel.refresh()
                        }
                    }"""

new_list = """                    } else if orderStore.orders.isEmpty {
                        EmptyStateView(icon: "shippingbox", title: "No local orders", message: "Your placed orders for this session will appear here.")
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 10) {
                                ForEach(orderStore.orders) { order in
                                    Button {
                                        selectedOrder = order
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Order #\(order.orderNumber)")
                                                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                                    .foregroundStyle(Color.brandWarmBlack)
                                                Text(order.createdAt.formatted(date: .long, time: .shortened))
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(Color.brandWarmGrey)
                                            }
                                            Spacer()
                                            VStack(alignment: .trailing, spacing: 4) {
                                                Text(currency(order.totalAmount))
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundStyle(Color.brandWarmBlack)
                                                Text(order.status.capitalized)
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(Color(hex: "#C8913A"))
                                            }
                                        }
                                        .padding(14)
                                        .background(Color.brandLinen)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Color.brandPebble, lineWidth: 0.5)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(16)
                        }
                    }"""

code = code.replace(old_list, new_list)

sheet_code = """
            .sheet(item: $selectedOrder) { order in
                StandaloneReceiptSheet(placed: order)
            }"""

code = code.replace(".navigationTitle(\"Orders\")", ".navigationTitle(\"Orders\")" + sheet_code)

# Add StandaloneReceiptSheet
extra = """
// MARK: - StandaloneReceiptSheet
struct StandaloneReceiptSheet: View {
    let placed: PlacedOrder
    @Environment(\\ .dismiss) var dismiss

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
                            ForEach(Array(placed.items.enumerated()), id: \\ .element.id) { index, item in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.product.name).font(.system(size: 13)).foregroundStyle(Color.brandWarmBlack)
                                        HStack(spacing: 6) {
                                            Text("×\\(item.quantity)").font(.system(size: 11)).foregroundStyle(Color.brandWarmGrey)
                                            Text("@ ₹\\(Int(item.product.price))").font(.system(size: 11)).foregroundStyle(Color.brandWarmGrey)
                                        }
                                    }
                                    Spacer()
                                    Text("₹\\(Int(item.lineTotal))").font(.system(size: 13, weight: .medium)).foregroundStyle(Color.brandWarmBlack)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 10)
                                if index < placed.items.count - 1 { BrandDivider().padding(.leading, 16) }
                            }
                            BrandDivider()
                            HStack {
                                Text("Total").font(.system(size: 15, weight: .semibold)).foregroundStyle(Color.brandWarmBlack)
                                Spacer()
                                Text("₹\\(Int(placed.totalAmount))").font(.system(size: 20, weight: .semibold, design: .serif)).foregroundStyle(Color.brandWarmBlack)
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
"""

with open("SalesAssociate/Views/SalesAssociateOrdersView.swift", "w") as f:
    f.write(code + extra)

