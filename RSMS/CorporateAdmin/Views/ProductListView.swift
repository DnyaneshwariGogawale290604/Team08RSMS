import SwiftUI

public struct ProductListView: View {
    @ObservedObject private var sessionViewModel: SessionViewModel
    @StateObject private var viewModel = ProductViewModel()
    @State private var showingAddProduct = false
    @State private var selectedDetailProduct: Product?
    @State private var searchText = ""
    @State private var selectedFilter: String = "All"

    public init(sessionViewModel: SessionViewModel) {
        self.sessionViewModel = sessionViewModel
    }

    public var body: some View {
        NavigationStack {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 22) {
                        searchBar
                        statsRow
                        filtersRow

                        if viewModel.isLoading && filteredProducts.isEmpty {
                            LoadingView(message: "Loading Catalog...")
                                .frame(height: 320)
                        } else if filteredProducts.isEmpty {
                            EmptyStateView(
                                icon: searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "shippingbox" : "magnifyingglass",
                                title: searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No Products Yet" : "No Results",
                                message: searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                    ? "Add your first product to start building the catalog."
                                    : "Try a different product name, category, or SKU."
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.top, 12)
                        } else {
                            LazyVGrid(columns: gridColumns, spacing: 16) {
                                ForEach(filteredProducts) { product in
                                    BoutiqueProductCardView(product: product) {
                                        selectedDetailProduct = product
                                    }
                                }
                            }
                            .animation(.easeInOut(duration: 0.22), value: filteredProducts.map(\.id))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 88)
                    .navigationTitle("Catalog")
                }
                .background(CatalogTheme.background)
                .refreshable {
                    await viewModel.fetchProducts()
                }
                .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingAddProduct = true
                    } label: {
                        AppToolbarGlyph(systemImage: "plus", backgroundColor: CatalogTheme.deepAccent)
                    }
                    .buttonStyle(.plain)

                    CorporateAdminProfileButton(sessionViewModel: sessionViewModel)
                }
            }
            .task {
                await viewModel.fetchProducts()
            }
            .sheet(isPresented: $showingAddProduct) {
                AddEditProductView(viewModel: viewModel)
            }
            .sheet(item: $selectedDetailProduct) { product in
                BoutiqueProductDetailSheet(product: product)
            }
            .alert(
                "Product Error",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "Something went wrong.")
            }
        }
    }

    private var gridColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 16), GridItem(.flexible(), spacing: 16)]
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Product Catalog")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(CatalogTheme.primaryText)

            Text("Manage and oversee your brand's global catalog")
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(CatalogTheme.secondaryText)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(CatalogTheme.primary)

            TextField(
                "Search products...",
                text: $searchText,
                prompt: Text("Search products...").foregroundColor(CatalogTheme.mutedText)
            )
                .font(.system(size: 14))
                .foregroundColor(CatalogTheme.primaryText)
                .tint(CatalogTheme.deepAccent)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CatalogTheme.searchField)
        )
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatsCardView(
                title: "Total",
                value: "\(filteredProducts.count)",
                icon: "shippingbox.fill",
                color: CatalogTheme.primary
            )

            StatsCardView(
                title: "Active",
                value: "\(activeCount)",
                icon: "checkmark.circle.fill",
                color: Color(hex: "#2F8F62")
            )

            StatsCardView(
                title: "Inactive",
                value: "\(inactiveCount)",
                icon: "pause.circle.fill",
                color: Color(hex: "#B65B5B")
            )
        }
    }

    private var availableCategories: [String] {
        let cats = Set(viewModel.products.map { $0.category }).filter { !$0.isEmpty }
        return Array(cats).sorted()
    }
    
    private var allFilters: [String] {
        var filters = ["All", "Active", "Inactive"]
        for category in availableCategories where !filters.contains(category) {
            filters.append(category)
        }
        return filters
    }

    private var filtersRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(allFilters, id: \.self) { filter in
                    FilterChipView(
                        title: filter,
                        isSelected: selectedFilter == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
        }
    }

    private var searchFilteredProducts: [Product] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        if query.isEmpty {
            return viewModel.products
        }

        return viewModel.products.filter { product in
            product.name.localizedCaseInsensitiveContains(query) ||
            product.category.localizedCaseInsensitiveContains(query) ||
            (product.sku?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }

    private var filteredProducts: [Product] {
        let base: [Product]
        switch selectedFilter {
        case "All":
            base = searchFilteredProducts
        case "Active":
            base = searchFilteredProducts.filter { $0.isActive ?? true }
        case "Inactive":
            base = searchFilteredProducts.filter { !($0.isActive ?? true) }
        default:
            base = searchFilteredProducts.filter { $0.category == selectedFilter }
        }
        
        return base.sorted { p1, p2 in
            let a1 = p1.isActive ?? true
            let a2 = p2.isActive ?? true
            
            if a1 != a2 {
                return a1 && !a2
            }
            
            let s1 = p1.stockStatus
            let s2 = p2.stockStatus
            
            if s1 != s2 {
                return s1 < s2
            }
            
            return p1.name < p2.name
        }
    }

    private var activeCount: Int {
        filteredProducts.filter { $0.isActive ?? true }.count
    }

    private var inactiveCount: Int {
        filteredProducts.filter { !($0.isActive ?? true) }.count
    }
}

private struct StatsCardView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color // Retained to preserve call site signature

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Circle()
                    .fill(CatalogTheme.statsIconBackground)
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(CatalogTheme.statsIconColor)
            }

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(CatalogTheme.primaryText)

            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(CatalogTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
    }
}

private struct FilterChipView: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .white : CatalogTheme.chipInactiveText)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(isSelected ? CatalogTheme.primary : CatalogTheme.surface)
                )
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1.02 : 1)
        .animation(.easeInOut(duration: 0.25), value: isSelected)
    }
}

private struct ProductCardView: View {
    let product: Product
    let onTap: () -> Void
    let onView: () -> Void
    let onEdit: () -> Void

    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                ZStack {
                    CatalogTheme.imageBackground
                    productImage
                }
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                statusBadge
                    .padding(12)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(CatalogTheme.primaryText)
                    .lineLimit(2)
                    .frame(height: 44, alignment: .topLeading)

                Text(product.category)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(CatalogTheme.subtleCategory)
                    .lineLimit(1)

                HStack {
                    Text(formattedPrice(product.price))
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundColor(CatalogTheme.deepAccent)

                    Spacer()

                    HStack(spacing: 4) {
                        Image(systemName: product.stockStatus == .urgent ? "exclamationmark.triangle.fill" : "shippingbox.fill")
                            .font(.system(size: 10))
                        Text("\(product.stockQuantity ?? 0)")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(stockBadgeForeground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(stockBadgeBackground)
                    )
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 250, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(CatalogTheme.card)
        )
        .opacity(product.isActive ?? true ? 1 : 0.82)
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        .scaleEffect(isPressed ? 1.02 : 1)
        .animation(.easeInOut(duration: 0.25), value: isPressed)
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture(minimumDuration: 0.01, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }

    @ViewBuilder
    private var productImage: some View {
        if let firstImageUrl = product.allImageUrls.first,
           let url = URL(string: firstImageUrl) {
            GeometryReader { proxy in
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    default:
                        imagePlaceholder
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
            }
        } else {
            imagePlaceholder
        }
    }

    private var imagePlaceholder: some View {
        ZStack {
            CatalogTheme.imageBackground

            Image(systemName: "photo")
                .font(.system(size: 28, weight: .light))
                .foregroundColor(CatalogTheme.mutedText)
        }
    }

    private var statusBadge: some View {
        let isActive = product.isActive ?? true
        return Text(isActive ? "Active" : "Inactive")
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(isActive ? .white : CatalogTheme.inactiveBadgeText)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isActive ? CatalogTheme.primary : CatalogTheme.inactiveBadge)
            )
    }

    private var stockBadgeForeground: Color {
        switch product.stockStatus {
        case .urgent:
            return CatalogTheme.deepAccent
        case .low:
            return CatalogTheme.primary
        case .normal:
            return CatalogTheme.secondaryText
        }
    }

    private var stockBadgeBackground: Color {
        switch product.stockStatus {
        case .urgent:
            return CatalogTheme.surface
        case .low:
            return CatalogTheme.elevatedCard
        case .normal:
            return CatalogTheme.surface.opacity(0.6)
        }
    }

    private var makingPriceText: String {
        if let makingPrice = product.makingPrice {
            return "Making: \(formattedPrice(makingPrice))"
        }
        return "Making: Not set"
    }

    private func formattedPrice(_ value: Double) -> String {
        String(format: "₹%.2f", value)
    }
}

private struct CorporateProductDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let product: Product
    let onEdit: () -> Void
    @State private var selectedVariantId: UUID?

    private var selectedVariant: ProductVariant {
        if let selectedVariantId,
           let variant = product.displayVariants.first(where: { $0.id == selectedVariantId }) {
            return variant
        }

        return product.displayVariants[0]
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ProductImageCarousel(imageUrls: selectedVariant.imageUrls, height: 280) {
                        imagePlaceholder
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(product.name)
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundColor(CatalogTheme.primaryText)

                        if !product.category.isEmpty {
                            Text(product.category.uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(CatalogTheme.subtleCategory)
                                .tracking(1.2)
                        }

                        Text(formattedPrice(product.price))
                            .font(.system(size: 20, weight: .bold, design: .serif))
                            .foregroundColor(CatalogTheme.deepAccent)
                    }

                    if product.displayVariants.count > 1 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Select Variant")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(CatalogTheme.primaryText)

                            Menu {
                                ForEach(product.displayVariants) { variant in
                                    Button(variant.name) {
                                        selectedVariantId = variant.id
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedVariant.name)
                                        .foregroundColor(CatalogTheme.primaryText)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(CatalogTheme.secondaryText)
                                }
                                .padding(12)
                                .background(CatalogTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }
                        }
                    }

                    if let info = selectedVariant.infoText?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !info.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Info")
                                .font(.headline)
                                .foregroundColor(CatalogTheme.primaryText)

                            Text(info)
                                .font(.body)
                                .foregroundColor(CatalogTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(CatalogTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }
                }
                .padding(16)
            }
            .background(CatalogTheme.background.ignoresSafeArea())
            .navigationTitle("Product Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: {
                        AppToolbarGlyph(systemImage: "checkmark", backgroundColor: CatalogTheme.deepAccent)
                    }
                    .buttonStyle(.plain)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                        onEdit()
                    } label: {
                        AppToolbarGlyph(systemImage: "pencil", backgroundColor: CatalogTheme.deepAccent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .onAppear {
                selectedVariantId = product.displayVariants.first?.id
            }
        }
    }

    private var imagePlaceholder: some View {
        ZStack {
            CatalogTheme.imageBackground
            Image(systemName: "photo")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(CatalogTheme.mutedText)
        }
    }

    private func formattedPrice(_ value: Double) -> String {
        String(format: "₹%.2f", value)
    }
}

private struct ProductImageCarousel<Placeholder: View>: View {
    let imageUrls: [String]
    let height: CGFloat
    let placeholder: () -> Placeholder
    @State private var selectedIndex = 0

    var body: some View {
        ZStack {
            if imageUrls.isEmpty {
                placeholder()
            } else {
                carouselImage(imageUrls[safe: selectedIndex] ?? imageUrls[0])
                    .id(selectedIndex)
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.18), value: selectedIndex)
            }

            if imageUrls.count > 1 {
                HStack {
                    carouselButton(systemName: "chevron.left") {
                        selectedIndex = selectedIndex == 0 ? imageUrls.count - 1 : selectedIndex - 1
                    }

                    Spacer()

                    carouselButton(systemName: "chevron.right") {
                        selectedIndex = selectedIndex == imageUrls.count - 1 ? 0 : selectedIndex + 1
                    }
                }
                .padding(.horizontal, 8)

                VStack {
                    Spacer()

                    HStack(spacing: 5) {
                        ForEach(imageUrls.indices, id: \.self) { index in
                            Circle()
                                .fill(index == selectedIndex ? Color.white : Color.white.opacity(0.45))
                                .frame(width: index == selectedIndex ? 7 : 5, height: index == selectedIndex ? 7 : 5)
                                .onTapGesture {
                                    selectedIndex = index
                                }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.22))
                    .clipShape(Capsule())
                    .padding(.bottom, 8)
                }
            }
        }
        .frame(height: height)
    }

    @ViewBuilder
    private func carouselImage(_ imageUrl: String) -> some View {
        if let url = URL(string: imageUrl) {
            GeometryReader { proxy in
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .clipped()
                    default:
                        placeholder()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                }
            }
        } else {
            placeholder()
        }
    }

    private func carouselButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
                .background(Color.black.opacity(0.28))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
