import SwiftUI

public struct CatalogView: View {
    @StateObject private var catalogVM = CatalogViewModel()
    
    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                CatalogTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search Bar
                    HStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(CatalogTheme.primary)
                        TextField(
                            "Search products or SKU...",
                            text: $catalogVM.searchText,
                            prompt: Text("Search products or SKU...").foregroundColor(CatalogTheme.mutedText)
                        )
                            .foregroundColor(CatalogTheme.primaryText)
                            .tint(CatalogTheme.deepAccent)
                            .autocapitalization(.none)
                    }
                    .padding(.horizontal, 14)
                    .frame(height: 44)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(CatalogTheme.surface)
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
                    
                    Divider().background(CatalogTheme.divider)
                    
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
                                    ProductCard(product: product)
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
                .foregroundColor(isSelected ? .white : CatalogTheme.chipInactiveText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? CatalogTheme.primary : CatalogTheme.surface)
                .clipShape(RoundedRectangle(cornerRadius: AppTheme.buttonCornerRadius, style: .continuous))
        }
    }
}

// MARK: - Product Card

struct ProductCard: View {
    let product: Product
    @State private var isPressed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Product icon area
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(CatalogTheme.imageBackground)
                    .frame(maxWidth: .infinity)
                    .frame(height: 140)
                
                if let imageUrl = product.imageUrl,
                   !imageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                   let url = URL(string: imageUrl) {
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
                            case .failure:
                                fallbackIcon(for: product)
                                    .frame(width: proxy.size.width, height: proxy.size.height)
                            @unknown default:
                                fallbackIcon(for: product)
                                    .frame(width: proxy.size.width, height: proxy.size.height)
                            }
                        }
                    }
                    .frame(height: 140)
                } else {
                    fallbackIcon(for: product)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 140)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            // Product info
            VStack(alignment: .leading, spacing: 6) {
                Text(product.name)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(CatalogTheme.primaryText)
                    .lineLimit(2)
                    .frame(height: 44, alignment: .topLeading)

                if !product.category.isEmpty {
                    Text(product.category)
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(CatalogTheme.subtleCategory)
                        .lineLimit(1)
                }

                if product.price > 0 {
                    Text(formatPrice(product.price))
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(CatalogTheme.deepAccent)
                        .padding(.top, 2)
                }

            }
            .padding(12)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 290, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(CatalogTheme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(CatalogTheme.divider, lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
        .scaleEffect(isPressed ? 1.02 : 1)
        .animation(.easeInOut(duration: 0.25), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.01, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
    
    @ViewBuilder
    private func fallbackIcon(for product: Product) -> some View {
        VStack(spacing: 6) {
            Image(systemName: iconForCategory(product.category))
                .font(.system(size: 36))
                .foregroundColor(CatalogTheme.mutedText)
            
            if !product.category.isEmpty {
                Text(product.category.uppercased())
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(CatalogTheme.mutedText)
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
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "$\(Int(value))"
    }
}
