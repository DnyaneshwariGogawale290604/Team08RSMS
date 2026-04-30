import SwiftUI

struct CatalogView: View {
    @StateObject private var catalogVM = CatalogViewModel()
    @State private var selectedProduct: Product?
    
    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ]
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                BoutiqueTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(BoutiqueTheme.primary)
                        TextField(
                            "Search products or SKU...",
                            text: $catalogVM.searchText,
                            prompt: Text("Search products or SKU...").foregroundColor(BoutiqueTheme.mutedText)
                        )
                            .foregroundColor(BoutiqueTheme.primaryText)
                            .tint(BoutiqueTheme.deepAccent)
                            .autocapitalization(.none)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(BoutiqueTheme.surface)
                    )
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    
                    // Category Pills
                    if !catalogVM.categories.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                CategoryPill(label: "All", isSelected: catalogVM.selectedCategory == nil) {
                                    catalogVM.selectedCategory = nil
                                }
                                ForEach(catalogVM.categories, id: \.self) { cat in
                                    CategoryPill(label: cat, isSelected: catalogVM.selectedCategory == cat) {
                                        catalogVM.selectedCategory = (catalogVM.selectedCategory == cat) ? nil : cat
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        }
                    }
                    

                    
                    // Content
                    if catalogVM.isLoading {
                        Spacer()
                        LoadingView(message: "Loading catalog...")
                        Spacer()
                    } else if let error = catalogVM.errorMessage {
                        Spacer()
                        EmptyStateView(icon: "exclamationmark.circle", title: "Catalog unavailable", message: error)
                        Spacer()
                    } else if catalogVM.filteredProducts.isEmpty {
                        Spacer()
                        EmptyStateView(icon: "tag.slash", title: "No products found", message: "Try a different search or category.")
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(catalogVM.filteredProducts) { product in
                                    BoutiqueProductCardView(product: product) {
                                        selectedProduct = product
                                    }
                                }
                            }
                            .padding(16)
                        }
                    }
                }
            }
            .navigationTitle("Catalog")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    BoutiqueProfileButton()
                }
            }
            
            .onAppear {
                catalogVM.fetchProducts()
            }
            .sheet(item: $selectedProduct) { product in
                BoutiqueProductDetailSheet(product: product)
            }
        }
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : BoutiqueTheme.chipInactiveText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? BoutiqueTheme.primary : BoutiqueTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
        }
    }
}

// MARK: - Product Card

struct BoutiqueProductCardView: View {
    let product: Product
    let onTap: () -> Void
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

    private func formattedPrice(_ value: Double) -> String {
        String(format: "₹%.2f", value)
    }
}

struct BoutiqueProductDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    let product: Product
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
                    BoutiqueProductImageCarousel(imageUrls: selectedVariant.imageUrls, height: 280) {
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

struct BoutiqueProductImageCarousel<Placeholder: View>: View {
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
