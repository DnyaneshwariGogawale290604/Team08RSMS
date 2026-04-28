import SwiftUI

struct SalesAssociateDashboardView: View {
    @ObservedObject private var sessionViewModel: SessionViewModel
    @StateObject private var viewModel = SalesAssociateViewModel()
    // Observe the shared cache so the rating card updates the moment a new
    // rating is submitted — without any additional Supabase fetch.
    @ObservedObject private var ratingCache = RatingCache.shared
    @State private var showCatalog = false
    @State private var catalogSearch = ""

    init(sessionViewModel: SessionViewModel) {
        self.sessionViewModel = sessionViewModel
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.luxuryBackground.ignoresSafeArea()

                if viewModel.isLoading && viewModel.recentOrders.isEmpty {
                    LoadingView(message: "Loading dashboard...")
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            greetingHeader
                            salesMetricsSection
                            ratingSection
                            trendingSection
                            catalogSection
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 40)
                    }
                    .refreshable {
                        await viewModel.refresh()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("DASHBOARD")
                        .font(.system(size: 13, weight: .semibold))
                        .kerning(2)
                        .foregroundStyle(Color.luxuryPrimaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    SalesAssociateProfileButton(sessionViewModel: sessionViewModel)
                }
            }
            .task {
                await viewModel.refresh()
            }
            .onAppear {
                Task {
                    await viewModel.refresh()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshSalesAssociateDashboard"))) { _ in
                Task {
                    await viewModel.refresh()
                }
            }
        }
    }

    private var greetingHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingTime())
                .font(BrandFont.body(13))
                .foregroundStyle(Color.luxurySecondaryText)
            Text("Sales Associate")
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(Color.luxuryPrimaryText)
        }
        .padding(.horizontal, 16)
    }

    private var salesMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "TODAY'S PERFORMANCE")

            if viewModel.todayOrderCount == 0 {
                emptyStateCard(icon: "chart.bar", text: "No performance data for today yet.")
            } else {
                HStack(spacing: 12) {
                    statCard(title: "Today Sales", value: currency(viewModel.todaySalesAmount), subtitle: "Revenue")
                    statCard(title: "Orders", value: "\(viewModel.todayOrderCount)", subtitle: "Today")
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "MY RATING")
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", ratingCache.averageRating))
                            .font(.system(size: 38, weight: .semibold, design: .serif))
                            .foregroundStyle(Color.luxuryPrimaryText)
                        Text("/ 5")
                            .font(BrandFont.body(16))
                            .foregroundStyle(Color.luxurySecondaryText)
                    }
                    Text(ratingCache.ratingsCount == 1 ? "1 review" : "\(ratingCache.ratingsCount) reviews")
                        .font(BrandFont.body(12))
                        .foregroundStyle(Color.luxurySecondaryText)
                }
                Spacer()
                HStack(spacing: 5) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: Double(star) <= ratingCache.averageRating ? "star.fill" : "star")
                            .foregroundStyle(Double(star) <= ratingCache.averageRating ? Color.init(hex: "#C8913A") ?? .yellow : Color.luxuryDivider)
                            .font(.title3)
                    }
                }
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
            .padding(.horizontal, 16)
        }
    }

    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "TRENDING PRODUCTS")
            emptyStateCard(icon: "arrow.up.right", text: "No trend data available yet.")
        }
    }

    private var catalogSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("PRODUCT CATALOG")
                    .font(.system(size: 11, weight: .semibold))
                    .kerning(1.2)
                    .foregroundStyle(Color.luxurySecondaryText)
                Spacer()
                Button {
                    withAnimation { showCatalog.toggle() }
                    if showCatalog && viewModel.catalog.isEmpty {
                        Task { await viewModel.fetchCatalog() }
                    }
                } label: {
                    Text(showCatalog ? "Hide" : "Show all")
                        .font(BrandFont.body(13))
                        .foregroundStyle(Color.luxuryPrimary)
                }
            }
            .padding(.horizontal, 16)

            if showCatalog {
                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.luxuryPrimary)
                            .font(.system(size: 14))
                        TextField("Search products...", text: $catalogSearch)
                            .font(BrandFont.body(14))
                            .foregroundStyle(Color.luxuryPrimaryText)
                            .onChange(of: catalogSearch) { newSearch in
                                Task { await viewModel.fetchCatalog(search: newSearch) }
                            }
                    }
                    .padding(16)
                    .background(Color.luxurySurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 16)

                    if viewModel.catalog.isEmpty {
                        emptyStateCard(icon: "tag.slash", text: "No products matched.")
                    } else {
                        LazyVGrid(columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ], spacing: 16) {
                            ForEach(viewModel.catalog) { product in
                                AssociateProductCard(product: product)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }

    private func greetingTime() -> String {
        let h = Calendar.current.component(.hour, from: Date())
        if h < 12 { return "Good morning," }
        if h < 17 { return "Good afternoon," }
        return "Good evening,"
    }

    private func emptyStateCard(icon: String, text: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(Color.luxuryMutedText)
            Text(text)
                .font(BrandFont.body(13))
                .foregroundStyle(Color.luxurySecondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    private func sectionHeader(title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .kerning(1.2)
            .foregroundStyle(Color.luxurySecondaryText)
            .padding(.horizontal, 16)
    }

    private func statCard(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .kerning(1.2)
                .foregroundStyle(Color.luxurySecondaryText)
            Text(value)
                .font(BrandFont.display(24))
                .foregroundStyle(Color.luxuryDeepAccent)
            Text(subtitle)
                .font(BrandFont.body(12))
                .foregroundStyle(Color.luxurySecondaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "₹\(formatter.string(from: NSNumber(value: value)) ?? "0")"
    }
}

struct AssociateProductCard: View {
    let product: Product
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Product Image Placeholder/Container
            ZStack {
                Color.luxurySurface
                
                if let imageUrl = product.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundStyle(Color.luxuryDivider)
                        }
                    }
                } else {
                    Image(systemName: "tag")
                        .font(.system(size: 24))
                        .foregroundStyle(Color.luxuryPrimary.opacity(0.5))
                }
            }
            .frame(height: 140)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .clipped()
            
            VStack(alignment: .leading, spacing: 4) {
                Text(product.name)
                    .font(BrandFont.body(14, weight: .semibold))
                    .foregroundStyle(Color.luxuryPrimaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(height: 38, alignment: .topLeading)
                
                Text(product.category)
                    .font(BrandFont.body(11))
                    .foregroundStyle(Color.luxurySecondaryText)
                
                Spacer(minLength: 4)
                
                HStack {
                    Text("₹\(Int(product.price))")
                        .font(BrandFont.body(14, weight: .bold))
                        .foregroundStyle(Color.luxuryDeepAccent)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.luxuryDivider)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 12)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}
