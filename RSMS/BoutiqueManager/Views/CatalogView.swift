import SwiftUI

public struct CatalogView: View {
    @StateObject private var catalogVM = CatalogViewModel()
    @State private var selectedProduct: Product?
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    public init() {}
    
    public var body: some View {
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
                                    ProductCard(product: product) {
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

struct ProductCard: View {
    let product: Product
    let onTap: () -> Void
    @State private var isPressed = false
    @State private var selectedSize: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Product image / icon area
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(BoutiqueTheme.imageBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 130)

                if !product.allImageUrls.isEmpty {
                    BoutiqueProductImageCarousel(imageUrls: product.allImageUrls, height: 130) {
                        fallbackIcon(for: product)
                    }
                    .frame(height: 130)
                } else {
                    fallbackIcon(for: product)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            // Product info
            VStack(alignment: .leading, spacing: 6) {

                // Name
                Text(product.name)
                    .font(.system(size: 13, weight: .bold, design: .serif))
                    .foregroundColor(BoutiqueTheme.primaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                // Category
                if !product.category.isEmpty {
                    Text(product.category.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(BoutiqueTheme.subtleCategory)
                        .tracking(1.2)
                        .lineLimit(1)
                }

                // Size selector
                if let sizes = product.sizeOptions, !sizes.isEmpty {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("SIZES")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(BoutiqueTheme.mutedText)
                            .tracking(1.5)

                        // Wrap chips: use a simple FlowLayout approximation
                        SizeChipRow(sizes: sizes, selectedSize: $selectedSize)
                    }
                    .padding(.top, 2)
                }

                Spacer(minLength: 0)

                // Price
                if product.price > 0 {
                    Text(formatPrice(product.price))
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(BoutiqueTheme.deepAccent)
                }

            }
            .padding(10)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 240, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(BoutiqueTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BoutiqueTheme.divider, lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
        .scaleEffect(isPressed ? 1.02 : 1)
        .animation(.easeInOut(duration: 0.25), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.01, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .onTapGesture {
            onTap()
        }
    }

    @ViewBuilder
    private func fallbackIcon(for product: Product) -> some View {
        VStack(spacing: 6) {
            Image(systemName: iconForCategory(product.category))
                .font(.system(size: 32))
                .foregroundColor(BoutiqueTheme.mutedText)

            if !product.category.isEmpty {
                Text(product.category.uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(BoutiqueTheme.mutedText)
                    .tracking(1.5)
            }
        }
    }

    private func iconForCategory(_ category: String) -> String {
        switch category.lowercased() {
        case "bags", "handbags": return "bag"
        case "shoes", "footwear": return "shoeprints.fill"
        case "watches": return "clock"
        case "jewellery", "jewelry": return "sparkles"
        case "clothing", "apparel": return "tshirt"
        case "accessories": return "sparkle"
        case "fragrance", "perfume": return "drop"
        case "sunglasses", "eyewear": return "eyeglasses"
        default: return "tag"
        }
    }

    private func formatPrice(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
    }
}

// MARK: - Size Chip Row (wrapping layout)

struct SizeChipRow: View {
    let sizes: [String]
    @Binding var selectedSize: String?

    var body: some View {
        // Show up to 6 sizes in a scrollable horizontal row
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(sizes.prefix(8), id: \.self) { size in
                    SizeChip(
                        label: size,
                        isSelected: selectedSize == size
                    ) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedSize = (selectedSize == size) ? nil : size
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Individual Size Chip

struct SizeChip: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 10, weight: isSelected ? .bold : .medium))
                .foregroundColor(isSelected ? .white : BoutiqueTheme.primary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isSelected ? BoutiqueTheme.primary : BoutiqueTheme.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(
                            isSelected ? BoutiqueTheme.primary : BoutiqueTheme.primary.opacity(0.35),
                            lineWidth: isSelected ? 0 : 0.8
                        )
                )
                .shadow(
                    color: isSelected ? BoutiqueTheme.primary.opacity(0.3) : .clear,
                    radius: 3, x: 0, y: 1
                )
        }
        .buttonStyle(.plain)
    }
}

private struct BoutiqueProductDetailSheet: View {
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
                        detailPlaceholder
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(product.name)
                            .font(.system(size: 24, weight: .bold, design: .serif))
                            .foregroundColor(BoutiqueTheme.primaryText)

                        if !product.category.isEmpty {
                            Text(product.category.uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(BoutiqueTheme.subtleCategory)
                                .tracking(1.2)
                        }

                        if product.price > 0 {
                            Text(formatPrice(product.price))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(BoutiqueTheme.deepAccent)
                        }
                    }

                    if product.displayVariants.count > 1 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Select Variant")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(BoutiqueTheme.primaryText)

                            Menu {
                                ForEach(product.displayVariants) { variant in
                                    Button(variant.name) {
                                        selectedVariantId = variant.id
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(selectedVariant.name)
                                        .foregroundColor(BoutiqueTheme.primaryText)
                                    Spacer()
                                    Image(systemName: "chevron.down")
                                        .foregroundColor(BoutiqueTheme.secondaryText)
                                }
                                .padding(12)
                                .background(BoutiqueTheme.card)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }

                    if let info = selectedVariant.infoText?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !info.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Info")
                                .font(.headline)
                                .foregroundColor(BoutiqueTheme.primaryText)

                            Text(info)
                                .font(.body)
                                .foregroundColor(BoutiqueTheme.secondaryText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(BoutiqueTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(BoutiqueTheme.divider, lineWidth: 0.5)
                        )
                    }
                }
                .padding(16)
            }
            .background(BoutiqueTheme.background.ignoresSafeArea())
            .navigationTitle("Product Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                selectedVariantId = product.displayVariants.first?.id
            }
        }
    }

    private var detailPlaceholder: some View {
        ZStack {
            BoutiqueTheme.imageBackground
            Image(systemName: "photo")
                .font(.system(size: 36, weight: .light))
                .foregroundColor(BoutiqueTheme.mutedText)
        }
    }

    private func formatPrice(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "INR"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
    }
}

private struct BoutiqueProductImageCarousel<Placeholder: View>: View {
    let imageUrls: [String]
    let height: CGFloat
    let placeholder: () -> Placeholder
    @State private var selectedIndex = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            if imageUrls.isEmpty {
                placeholder()
            } else {
                TabView(selection: $selectedIndex) {
                    ForEach(Array(imageUrls.enumerated()), id: \.offset) { index, imageUrl in
                        carouselImage(imageUrl)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }

            if imageUrls.count > 1 {
                HStack(spacing: 5) {
                    ForEach(imageUrls.indices, id: \.self) { index in
                        Circle()
                            .fill(index == selectedIndex ? Color.white : Color.white.opacity(0.45))
                            .frame(width: index == selectedIndex ? 7 : 5, height: index == selectedIndex ? 7 : 5)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.black.opacity(0.22))
                .clipShape(Capsule())
                .padding(.bottom, 8)
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
                    case .empty:
                        ProgressView()
                            .frame(width: proxy.size.width, height: proxy.size.height)
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
}
