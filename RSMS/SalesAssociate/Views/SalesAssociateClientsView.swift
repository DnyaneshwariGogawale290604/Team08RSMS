import SwiftUI
import Supabase
import PostgREST

struct SalesAssociateClientsView: View {
    @ObservedObject private var sessionViewModel: SessionViewModel
    @StateObject private var viewModel = SalesAssociateViewModel()
    @StateObject private var customerVM = AssociateSalesViewModel()
    
    @State private var searchText = ""
    @State private var filter = "All"
    @State private var showCreateCustomer = false
    @State private var customerToDelete: Customer?
    @State private var showDeleteAlert = false
    
    init(sessionViewModel: SessionViewModel) {
        self.sessionViewModel = sessionViewModel
    }
    
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
                Color.luxuryBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search & Filters
                    VStack(spacing: 16) {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass").foregroundStyle(Color.luxuryPrimary).font(.system(size: 14))
                            TextField("Search by name, phone or email...", text: $searchText)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.luxuryPrimaryText)
                                .autocorrectionDisabled()
                        }
                        .padding(16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
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
                                    .foregroundStyle(Color.luxurySecondaryText)
                                    .padding(.top, 16)
                                    .padding(.bottom, 4)
                                
                                ForEach(filteredCustomers) { customer in
                                    SwipeableCustomerCard(onDelete: {
                                        customerToDelete = customer
                                        showDeleteAlert = true
                                    }) {
                                        NavigationLink {
                                            ClientProfileView(customer: customer)
                                        } label: {
                                            HStack(spacing: 12) {
                                                Circle()
                                                    .fill(Color.luxurySurface)
                                                    .frame(width: 44, height: 44)
                                                    .overlay(
                                                        Text(String(customer.name.prefix(1)).uppercased())
                                                            .font(.system(size: 16, weight: .semibold, design: .serif))
                                                            .foregroundStyle(Color.luxuryPrimary)
                                                    )
                                                
                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text(customer.name)
                                                        .font(BrandFont.body(15, weight: .semibold))
                                                        .foregroundStyle(Color.luxuryPrimaryText)
                                                    Text(customer.phone ?? customer.email ?? "No contact")
                                                        .font(BrandFont.body(12))
                                                        .foregroundStyle(Color.luxurySecondaryText)
                                                }
                                                
                                                Spacer()
                                                
                                                if let category = customer.customerCategory {
                                                    Text(category)
                                                        .font(.system(size: 9, weight: .bold))
                                                        .padding(.horizontal, 8)
                                                        .padding(.vertical, 4)
                                                        .background(category.lowercased() == "vip" ? Color(hex: "#C8913A").opacity(0.15) : Color.luxurySurface)
                                                        .foregroundStyle(category.lowercased() == "vip" ? Color(hex: "#C8913A") : Color.luxurySecondaryText)
                                                        .clipShape(Capsule())
                                                }
                                                
                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(Color.luxuryMutedText)
                                            }
                                            .padding(.vertical, 14)
                                            .padding(.horizontal, 16)
                                            .background(Color.white)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                                        }
                                        .buttonStyle(LuxuryPressStyle())
                                    }
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
            .alert("Delete Client", isPresented: $showDeleteAlert, presenting: customerToDelete) { customer in
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteCustomer(customerId: customer.id)
                    }
                }
            } message: { customer in
                Text("Are you sure you want to delete \(customer.name)? This action cannot be undone.")
            }
            .navigationTitle("Clients")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        customerVM.errorMessage = nil
                        showCreateCustomer = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Color.luxuryPrimaryText)
                            .frame(width: 30, height: 30)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    SalesAssociateProfileButton(sessionViewModel: sessionViewModel)
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
                .background(filter == title ? Color.luxurySelection : Color.luxurySurface)
                .foregroundStyle(filter == title ? Color.white : Color.luxuryDeepAccent)
                .clipShape(Capsule())
        }
    }
    
    struct ClientProfileView: View {
        let customer: Customer
        @State private var orders: [SAOrder] = []
        @State private var isLoading = false
        
        // AI Recommendations state
        @State private var recommendedProducts: [Product] = []
        @State private var isFetchingRecommendations = false
        @State private var recommendationDiagnosticMessage: String?
        
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
                    Color.luxuryBackground.ignoresSafeArea()
                    
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            // Header Profile Card
                            VStack(spacing: 12) {
                                Circle()
                                    .fill(Color.luxurySurface)
                                    .frame(width: 80, height: 80)
                                    .overlay(
                                        Text(String(customer.name.prefix(1)))
                                            .font(.system(size: 32, weight: .semibold, design: .serif))
                                            .foregroundStyle(Color.luxuryPrimary)
                                    )
                                
                                Text(customer.name)
                                    .font(.system(size: 24, weight: .semibold, design: .serif))
                                    .foregroundStyle(Color.luxuryPrimaryText)
                                
                                if let category = customer.customerCategory {
                                    Text(category)
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(category.lowercased() == "vip" ? Color(hex: "#C8913A").opacity(0.15) : Color.luxurySurface)
                                        .foregroundStyle(category.lowercased() == "vip" ? Color(hex: "#C8913A") : Color.luxurySecondaryText)
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
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
                            .padding(.horizontal, 16)
                            
                            // Stats Highlights
                            HStack(spacing: 12) {
                                statCard(icon: "indianrupeesign", label: "Total Spent", value: formatINR(totalSpent))
                                statCard(icon: "shippingbox", label: "Orders", value: "\(mergedOrders.count)")
                                statCard(icon: "calendar", label: "Last Purchase", value: lastPurchaseDate)
                            }
                            .padding(.horizontal, 16)
                            
                            // AI Stylist Recommendations
                            aiRecommendationsSection
                            
                            // Purchase History
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Purchase History")
                                    .font(.system(size: 18, weight: .bold, design: .serif))
                                    .foregroundColor(CatalogTheme.primaryText)
                                    .padding(.horizontal, 16)
                                
                                if isLoading && mergedOrders.isEmpty {
                                    ProgressView()
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, 20)
                                } else if mergedOrders.isEmpty {
                                    Text("No previous orders found.")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Color.luxurySecondaryText)
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
                        Text("Client Profile")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.luxuryPrimaryText)
                    }
                    ToolbarItem(placement: .topBarLeading) {
                        Button { dismiss() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(Color.luxuryPrimaryText)
                                .frame(width: 32, height: 32)
                                .background(Color.white)
                                .clipShape(Circle())
                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                        }
                    }
                }
                .task {
                    await fetchOrders()
                    await fetchAIRecommendations()
                }
            }
        }
        
        // MARK: - AI Recommendations UI
        private var aiRecommendationsSection: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color(hex: "#C8913A"))
                    Text("Ai Stylist Picks")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(CatalogTheme.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                
                if isFetchingRecommendations {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 120)
                } else if recommendedProducts.isEmpty {
                    Text(recommendationDiagnosticMessage ?? "No recommendations available right now.")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.luxurySecondaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(recommendedProducts) { product in
                                AIRecoCard(product: product)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
        
        private func infoRow(icon: String, label: String, value: String) -> some View {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.luxuryPrimary)
                    .frame(width: 20)
                Text(label)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.luxurySecondaryText)
                Spacer()
                Text(value)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.luxuryPrimaryText)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        
        private func divider() -> some View {
            Divider()
                .background(Color.luxuryDivider)
                .padding(.leading, 48)
        }
        
        private func statCard(icon: String, label: String, value: String) -> some View {
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(Color.luxuryPrimary)
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .serif))
                    .foregroundStyle(Color.luxuryDeepAccent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(Color.luxurySecondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .leading)
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
        
        private func orderRow(order: SAOrder) -> some View {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Order #\(order.id.uuidString.prefix(8).uppercased())")
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color.luxuryPrimaryText)
                    Text(order.createdAt?.components(separatedBy: "T").first ?? "--")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.luxurySecondaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 6) {
                    Text("₹\(Int(order.totalAmount))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.luxuryDeepAccent)
                    Text((order.status ?? "pending").capitalized)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color.luxurySecondaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#D8C6C6"))
                        .clipShape(Capsule())
                }
            }
            .padding(14)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
        
        private func formatINR(_ v: Double) -> String {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.maximumFractionDigits = 0
            return f.string(from: NSNumber(value: v)) ?? "\(Int(v))"
        }
        
        private func fetchOrders() async {
            isLoading = true
            defer { isLoading = false }
            do {
                let fetched: [SAOrder] = try await SupabaseManager.shared.client
                    .from("sales_orders")
                    .select("order_id,total_amount,status,created_at,customers(name)")
                    .eq("customer_id", value: customer.id.uuidString)
                    .order("created_at", ascending: false)
                    .limit(20)
                    .execute()
                    .value
                self.orders = fetched
            } catch is CancellationError {
                // Pull-to-refresh cancellation from SwiftUI — do nothing.
            } catch {
                print("Failed to fetch client orders: \(error)")
            }
        }
        
        // MARK: - Fetch AI Logic
        private func fetchAIRecommendations() async {
            isFetchingRecommendations = true
            defer { isFetchingRecommendations = false }
            
            do {
                // 1. Fetch your store's active catalog
                let catalog: [Product] = try await SupabaseManager.shared.client
                    .from("products")
                    .select("*, product_variants(*)")
                    .eq("brand_id", value: customer.brandId?.uuidString ?? "")
                    .eq("is_active", value: true)
                    .execute()
                    .value
                
                // 2. Fetch past products bought by this customer for AI context
                struct OrderItemRow: Decodable {
                    struct ProductData: Decodable {
                        let name: String?
                        let category: String?
                    }
                    let products: ProductData?
                }
                
                let pastOrderIds = self.orders.map { $0.id.uuidString }
                var pastContext = ""
                
                if !pastOrderIds.isEmpty {
                    if let pastItems: [OrderItemRow] = try? await SupabaseManager.shared.client
                        .from("order_items")
                        .select("products(name, category)")
                        .in("order_id", values: pastOrderIds)
                        .limit(10)
                        .execute()
                        .value {
                        let names = pastItems.compactMap { $0.products?.name }
                        if !names.isEmpty {
                            pastContext = "Previously bought: \(names.joined(separator: ", ")). "
                        }
                    }
                }
                
                // 3. Create a "dummy" cart based on the client's preferences and past purchases
                let clientContextProduct = Product(
                    id: UUID(),
                    name: "\(pastContext)Client Prefers: \(customer.notes ?? "Luxury Goods")",
                    category: customer.customerCategory ?? "General",
                    price: 0.0
                )
                
                // 4. Call your Generative Service
                let result = await GenerativeRecommendationService.shared.getRecommendationsResult(
                    cartItems: [clientContextProduct],
                    availableCatalog: catalog
                )
                
                if result.products.isEmpty {
                    // Fallback: Random 2 products from catalog if catalog not empty
                    self.recommendedProducts = Array(catalog.shuffled().prefix(2))
                    self.recommendationDiagnosticMessage = "Curated picks from our latest collection."
                } else {
                    self.recommendedProducts = result.products
                    self.recommendationDiagnosticMessage = result.diagnosticMessage
                }
            } catch {
                print("Failed to fetch AI recommendations for profile: \(error)")
                // Try to fallback if possible
                recommendationDiagnosticMessage = "Discover these store favorites."
            }
        }
    }
    
    // MARK: - AI Stylist Card
    struct AIRecoCard: View {
        let product: Product
        
        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                // Product image
                ZStack {
                    Color.luxurySurface
                    
                    if let imageUrl = product.displayImageUrl, let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable()
                                    .aspectRatio(contentMode: .fill)
                            default:
                                Image(systemName: "photo")
                                    .foregroundStyle(Color.luxuryMutedText.opacity(0.5))
                            }
                        }
                    } else {
                        Image(systemName: "photo")
                            .foregroundStyle(Color.luxuryMutedText.opacity(0.5))
                    }
                }
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(product.name)
                        .font(BrandFont.body(13, weight: .semibold))
                        .foregroundStyle(Color.luxuryPrimaryText)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                        .frame(height: 52, alignment: .topLeading)
                    
                    Text(product.category)
                        .font(BrandFont.body(11))
                        .foregroundStyle(Color.luxurySecondaryText)
                    
                    Text("₹\(Int(product.price))")
                        .font(.system(size: 13, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.luxuryDeepAccent)
                        .padding(.top, 2)
                }
            }
            .frame(width: 140, height: 260)
            .padding(10)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
        }
    }
}

// MARK: - Swipeable Customer Card
struct SwipeableCustomerCard<Content: View>: View {
    let onDelete: () -> Void
    let content: () -> Content
    
    @State private var offset: CGFloat = 0
    @State private var isSwiped = false
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Red delete background with bin icon
            Button {
                withAnimation {
                    offset = 0
                    isSwiped = false
                }
                onDelete()
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.red)
                    Image(systemName: "trash.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                }
                .frame(width: 70)
                .padding(.vertical, 1) // slight inset to stay clean
            }
            .padding(.trailing, 0)
            
            // The main card content
            content()
                .background(Color.luxuryBackground) // Matches parent to cover the red part
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onChanged { value in
                            if value.translation.width < 0 {
                                offset = value.translation.width
                            }
                        }
                        .onEnded { value in
                            withAnimation(.spring()) {
                                if value.translation.width < -60 {
                                    offset = -80
                                    isSwiped = true
                                } else {
                                    offset = 0
                                    isSwiped = false
                                }
                            }
                        }
                )
        }
    }
}
