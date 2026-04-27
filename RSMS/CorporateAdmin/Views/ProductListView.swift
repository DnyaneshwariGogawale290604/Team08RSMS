import SwiftUI

public struct ProductListView: View {
    private enum CatalogFilter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case inactive = "Inactive"
        case category = "Category"
    }

    @ObservedObject private var sessionViewModel: SessionViewModel
    @StateObject private var viewModel = ProductViewModel()
    @State private var showingAddProduct = false
    @State private var selectedProduct: Product?
    @State private var searchText = ""
    @State private var selectedFilter: CatalogFilter = .all

    public init(sessionViewModel: SessionViewModel) {
        self.sessionViewModel = sessionViewModel
    }

    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                CatalogTheme.background
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        headerSection
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
                                    ProductCardView(
                                        product: product,
                                        onTap: {
                                            selectedProduct = product
                                        },
                                        onView: {
                                            selectedProduct = product
                                        },
                                        onEdit: {
                                            selectedProduct = product
                                        }
                                    )
                                }
                            }
                            .animation(.easeInOut(duration: 0.22), value: filteredProducts.map(\.id))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 88)
                }
                .refreshable {
                    await viewModel.fetchProducts()
                }


            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingAddProduct = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: AppTheme.toolbarButtonSize, height: AppTheme.toolbarButtonSize)
                            .background(Circle().fill(CatalogTheme.deepAccent))
                            .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                    }
                }
            }
            .task {
                await viewModel.fetchProducts()
            }
            .sheet(isPresented: $showingAddProduct) {
                AddEditProductView(viewModel: viewModel)
            }
            .sheet(item: $selectedProduct) { product in
                AddEditProductView(viewModel: viewModel, editingProduct: product)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Catalog")
                .font(.system(size: 34, weight: .bold, design: .serif))
                .foregroundColor(CatalogTheme.primaryText)

            Text("Manage your product library")
                .font(.system(size: 15, weight: .regular, design: .default))
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
        .frame(height: 44)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CatalogTheme.searchField)
        )
    }

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatsCardView(
                title: "Total",
                value: "\(searchFilteredProducts.count)",
                icon: "shippingbox.fill"
            )

            StatsCardView(
                title: "Active",
                value: "\(activeCount)",
                icon: "checkmark.circle.fill"
            )

            StatsCardView(
                title: "Inactive",
                value: "\(inactiveCount)",
                icon: "pause.circle.fill"
            )
        }
    }

    private var filtersRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CatalogFilter.allCases, id: \.self) { filter in
                    FilterChipView(
                        title: filter.rawValue,
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
        switch selectedFilter {
        case .all:
            return searchFilteredProducts
        case .active:
            return searchFilteredProducts.filter { $0.isActive ?? true }
        case .inactive:
            return searchFilteredProducts.filter { !($0.isActive ?? true) }
        case .category:
            return searchFilteredProducts.sorted { $0.category < $1.category }
        }
    }

    private var activeCount: Int {
        searchFilteredProducts.filter { $0.isActive ?? true }.count
    }

    private var inactiveCount: Int {
        searchFilteredProducts.filter { !($0.isActive ?? true) }.count
    }
}

private struct StatsCardView: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Circle()
                    .fill(CatalogTheme.statsIconBackground)
                    .frame(width: 28, height: 28)

                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(CatalogTheme.statsIconColor)
            }

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(CatalogTheme.primaryText)

            Text(title)
                .font(.system(size: 12, weight: .regular))
                .foregroundColor(CatalogTheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CatalogTheme.card)
        )
        .shadow(color: Color.black.opacity(0.02), radius: 3, x: 0, y: 1)
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
                .padding(.vertical, 8)
                .background(
                    Capsule(style: .continuous)
                        .fill(isSelected ? CatalogTheme.primary : CatalogTheme.surface)
                )
        }
        .buttonStyle(.plain)
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
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(.system(size: 15, weight: .bold, design: .serif))
                    .foregroundColor(CatalogTheme.primaryText)
                    .lineLimit(2)
                    .frame(height: 44, alignment: .topLeading)

                Text(product.category)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(CatalogTheme.categoryText)
                    .lineLimit(1)

                Text(formattedPrice(product.price))
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(CatalogTheme.deepAccent)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 250, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CatalogTheme.card)
        )
        .grayscale(product.isActive ?? true ? 0 : 1.0)
        .opacity(product.isActive ?? true ? 1 : 0.4)
        .shadow(color: Color.black.opacity(0.02), radius: 3, x: 0, y: 1)
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
        if let imageUrl = product.imageUrl,
           !imageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
           let url = URL(string: imageUrl) {
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
            .frame(height: 140)
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
                Capsule(style: .continuous)
                    .fill(isActive ? CatalogTheme.primary : CatalogTheme.inactiveBadge)
            )
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
