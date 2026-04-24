import SwiftUI
import Supabase
import PostgREST

struct SalesAssociateClientsView: View {
    @StateObject private var viewModel = SalesAssociateViewModel()
    @StateObject private var customerVM = AssociateSalesViewModel()

    @State private var searchText = ""
    @State private var filter = "All"
    @State private var showCreateCustomer = false

    var filteredCustomers: [Customer] {
        let textFiltered = viewModel.customers.filter {
            searchText.isEmpty || 
            $0.name.localizedCaseInsensitiveContains(searchText) || 
            ($0.phone?.localizedCaseInsensitiveContains(searchText) == true) || 
            ($0.email?.localizedCaseInsensitiveContains(searchText) == true)
        }
        
        if filter == "All" {
            return textFiltered
        } else if filter == "VIP" {
            return textFiltered.filter { $0.customerCategory?.lowercased() == "vip" }
        } else {
            return textFiltered.filter { $0.customerCategory?.lowercased() == "regular" || $0.customerCategory == nil }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandOffWhite.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Search & Filters
                    VStack(spacing: 16) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass").foregroundStyle(Color.brandWarmGrey).font(.system(size: 14))
                            TextField("Search by name, phone or email...", text: $searchText)
                                .font(.system(size: 14))
                                .autocorrectionDisabled()
                        }
                        .padding(16)
                        .background(Color.brandLinen)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandPebble, lineWidth: 0.5))
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                        HStack(spacing: 10) {
                            filterPill("All")
                            filterPill("VIP")
                            filterPill("Regular")
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                    }

                    if let error = viewModel.errorMessage {
                        ErrorBanner(message: error) {
                            viewModel.errorMessage = nil
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                    }

                    if viewModel.isLoading && viewModel.customers.isEmpty {
                        Spacer()
                        LoadingView(message: "Loading clients...")
                        Spacer()
                    } else if filteredCustomers.isEmpty {
                        Spacer()
                        EmptyStateView(icon: "person.2", title: "No clients found", message: "Try adjusting your search or filters.")
                        Spacer()
                    } else {
                        ScrollView(showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("\(filteredCustomers.count) clients")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.brandWarmGrey)
                                    .padding(.top, 16)
                                    .padding(.bottom, 4)

                                ForEach(filteredCustomers) { customer in
                                    NavigationLink {
                                        ClientProfileView(customer: customer)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Circle()
                                                .fill(Color(hex: "#C8913A").opacity(0.15))
                                                .frame(width: 44, height: 44)
                                                .overlay(
                                                    Text(String(customer.name.prefix(1)).uppercased())
                                                        .font(.system(size: 16, weight: .semibold, design: .serif))
                                                        .foregroundStyle(Color.brandWarmBlack)
                                                )

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(customer.name)
                                                    .font(BrandFont.body(15, weight: .semibold))
                                                    .foregroundStyle(Color.brandWarmBlack)
                                                Text(customer.phone ?? customer.email ?? "No contact")
                                                    .font(BrandFont.body(12))
                                                    .foregroundStyle(Color.brandWarmGrey)
                                            }

                                            Spacer()

                                            if let category = customer.customerCategory {
                                                Text(category.uppercased())
                                                    .font(.system(size: 9, weight: .bold))
                                                    .kerning(1)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(category.lowercased() == "vip" ? Color(hex: "#C8913A").opacity(0.15) : Color.brandPebble.opacity(0.3))
                                                    .foregroundStyle(category.lowercased() == "vip" ? Color(hex: "#C8913A") : Color.brandWarmBlack)
                                                    .clipShape(Capsule())
                                            }
                                            
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 12))
                                                .foregroundStyle(Color.brandPebble)
                                        }
                                        .padding(.vertical, 14)
                                        .padding(.horizontal, 16)
                                        .background(Color.brandLinen)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandPebble, lineWidth: 0.5))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .refreshable {
                            await viewModel.fetchCustomers()
                        }
                    }
                }
            }
            .navigationTitle("Clients")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        customerVM.errorMessage = nil
                        showCreateCustomer = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.brandWarmBlack)
                    }
                }
            }
            .sheet(isPresented: $showCreateCustomer, onDismiss: {
                Task {
                    await viewModel.fetchCustomers()
                    await customerVM.fetchCustomers()
                }
            }) {
                CustomerSheet(vm: customerVM, initialMode: .create)
            }
            .task {
                await viewModel.fetchCustomers()
                await customerVM.fetchCustomers()
            }
        }
    }

    private func filterPill(_ title: String) -> some View {
        Button {
            filter = title
        } label: {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(filter == title ? Color.brandWarmBlack : Color.brandLinen)
                .foregroundStyle(filter == title ? Color.brandOffWhite : Color.brandWarmBlack)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.brandPebble, lineWidth: 0.5))
        }
    }
}
import SwiftUI

struct ClientProfileView: View {
    let customer: Customer
    @State private var orders: [SAOrder] = []
    @State private var isLoading = false
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var orderStore: SharedOrderStore

    var mergedOrders: [SAOrder] {
        let local = orderStore.orders.filter { $0.customer.id == customer.id }.map {
            SAOrder(
                id: $0.id,
                totalAmount: $0.totalAmount,
                status: $0.status,
                createdAt: $0.createdAt.ISO8601Format()
            )
        }
        let remote = orders.filter { rem in !local.contains(where: { $0.id == rem.id }) }
        return local + remote
    }

    var totalSpent: Double {
        mergedOrders.map(\.totalAmount).reduce(0, +)
    }

    var lastPurchaseDate: String {
        guard let first = mergedOrders.first(where: { $0.createdAt != nil }), let date = first.createdAt else { return "--" }
        return date.components(separatedBy: "T").first ?? date
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandOffWhite.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Header Profile Card
                        VStack(spacing: 12) {
                            Circle()
                                .fill(Color.brandPebble.opacity(0.4))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Text(String(customer.name.prefix(1)).uppercased())
                                        .font(.system(size: 32, weight: .semibold, design: .serif))
                                        .foregroundStyle(Color.brandWarmBlack)
                                )

                            Text(customer.name)
                                .font(.system(size: 24, weight: .semibold, design: .serif))
                                .foregroundStyle(Color.brandWarmBlack)

                            if let category = customer.customerCategory {
                                Text(category.uppercased())
                                    .font(.system(size: 9, weight: .bold))
                                    .kerning(1)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 4)
                                    .background(Color(hex: "#C8913A").opacity(0.15))
                                    .foregroundStyle(Color(hex: "#C8913A"))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.top, 20)

                        // Info Card
                        VStack(spacing: 0) {
                            if let phone = customer.phone { infoRow(icon: "phone", label: "Phone", value: phone); divider() }
                            if let email = customer.email { infoRow(icon: "envelope", label: "Email", value: email); divider() }
                            if let gender = customer.gender { infoRow(icon: "person", label: "Gender", value: gender); divider() }
                            if let dob = customer.dateOfBirth { infoRow(icon: "calendar", label: "Date of Birth", value: dob); divider() }
                            if let nationality = customer.nationality { infoRow(icon: "globe", label: "Nationality", value: nationality); divider() }
                            if let address = customer.address { infoRow(icon: "location", label: "Address", value: address); divider() }
                            if let notes = customer.notes { infoRow(icon: "doc.text", label: "Notes", value: notes); divider() }
                            
                            if let created = customer.createdAt {
                                infoRow(icon: "clock", label: "Client Since", value: created.formatted(date: .abbreviated, time: .omitted))
                            } else {
                                infoRow(icon: "clock", label: "Client Since", value: "--")
                            }
                        }
                        .background(Color.brandLinen)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandPebble, lineWidth: 0.5))
                        .padding(.horizontal, 16)

                        // Stats Highlights
                        HStack(spacing: 12) {
                            statCard(icon: "indianrupeesign", label: "Total Spent", value: formatINR(totalSpent))
                            statCard(icon: "shippingbox", label: "Orders", value: "\(mergedOrders.count)")
                            statCard(icon: "calendar", label: "Last Purchase", value: lastPurchaseDate)
                        }
                        .padding(.horizontal, 16)

                        // Purchase History
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PURCHASE HISTORY")
                                .font(.system(size: 11, weight: .semibold))
                                .kerning(1.2)
                                .foregroundStyle(Color.brandWarmGrey)
                                .padding(.horizontal, 16)

                            if isLoading && mergedOrders.isEmpty {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 20)
                            } else if mergedOrders.isEmpty {
                                Text("No previous orders found.")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Color.brandWarmGrey)
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 10)
                            } else {
                                VStack(spacing: 10) {
                                    ForEach(mergedOrders) { order in
                                        orderRow(order: order)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationBarBackButtonHidden(true)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("CLIENT PROFILE")
                        .font(.system(size: 13, weight: .semibold))
                        .kerning(2)
                        .foregroundStyle(Color.brandWarmBlack)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.brandWarmBlack)
                            .frame(width: 32, height: 32)
                            .background(Color.brandOffWhite)
                            .clipShape(Circle())
                    }
                }
            }
            .task {
                await fetchOrders()
            }
        }
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.brandWarmGrey)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.brandWarmGrey)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.brandWarmBlack)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private func divider() -> some View {
        Divider()
            .background(Color.brandPebble)
            .padding(.leading, 48)
    }

    private func statCard(icon: String, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.brandWarmGrey)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundStyle(Color.brandWarmBlack)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(Color.brandWarmGrey)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.brandLinen)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandPebble, lineWidth: 0.5))
    }

    private func orderRow(order: SAOrder) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Order #\(order.id.uuidString.prefix(8).uppercased())")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Color.brandWarmBlack)
                Text(order.createdAt?.components(separatedBy: "T").first ?? "--")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.brandWarmGrey)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("₹\(Int(order.totalAmount))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.brandWarmBlack)
                Text((order.status ?? "pending").capitalized)
                    .font(.system(size: 11))
                    .foregroundStyle(Color(hex: "#C8913A"))
            }
        }
        .padding(14)
        .background(Color.brandLinen)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.brandPebble, lineWidth: 0.5))
    }

    private func formatINR(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return "₹\(f.string(from: NSNumber(value: v)) ?? "\(Int(v))")"
    }

    private func fetchOrders() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let fetched: [SAOrder] = try await SupabaseManager.shared.client
                .from("sales_orders")
                .select("order_id,total_amount,status,created_at,customers(name)")
                .eq("customer_id", value: customer.id)
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value
            self.orders = fetched
        } catch {
            print("Failed to fetch client orders: \(error)")
        }
    }
}
