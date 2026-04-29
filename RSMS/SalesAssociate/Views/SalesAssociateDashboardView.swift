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
            sectionHeader(title: "MONTHLY PERFORMANCE")

            if viewModel.todayOrderCount == 0 {
                emptyStateCard(icon: "chart.bar", text: "No performance data for this month yet.")
            } else {
                HStack(spacing: 12) {
                    statCard(title: "Monthly Sales", value: currency(viewModel.todaySalesAmount), subtitle: "Revenue")
                    statCard(title: "Orders", value: "\(viewModel.todayOrderCount)", subtitle: "This Month")
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

            if viewModel.trendingProducts.isEmpty {
                emptyStateCard(icon: "arrow.up.right", text: "No trend data yet — complete some orders to see trending products.")
                    .padding(.horizontal, 16)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 14) {
                        ForEach(Array(viewModel.trendingProducts.enumerated()), id: \.element.id) { index, trend in
                            trendingCard(trend: trend, rank: index + 1)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func trendingCard(trend: TrendingProduct, rank: Int) -> some View {
        let isTop = rank == 1
        let accentColor: Color = isTop ? Color(hex: "#C8913A") : Color.luxuryPrimary
        let cardBg: Color = isTop ? Color(hex: "#FDF8F0") : Color.white

        return VStack(alignment: .leading, spacing: 0) {
            // Top row: rank + flames
            HStack(alignment: .center) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.15))
                        .frame(width: 30, height: 30)
                    Text("\(rank)")
                        .font(.system(size: 13, weight: .bold, design: .serif))
                        .foregroundStyle(accentColor)
                }
                Spacer()
                HStack(spacing: 2) {
                    ForEach(0..<trend.flameLevel, id: \.self) { _ in
                        Image(systemName: "flame.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(
                                trend.flameLevel == 3 ? Color(hex: "#C8913A")
                                : trend.flameLevel == 2 ? Color.luxuryPrimary
                                : Color.luxurySecondaryText
                            )
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Text(trend.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.luxuryPrimaryText)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 14)

            Text(trend.category.isEmpty ? "Product" : trend.category)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(accentColor.opacity(0.1))
                .clipShape(Capsule())
                .padding(.horizontal, 14)
                .padding(.top, 6)

            Spacer(minLength: 12)

            Rectangle()
                .fill(Color.luxuryDivider)
                .frame(height: 0.5)
                .padding(.horizontal, 14)

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(trend.soldCount)")
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundStyle(Color.luxuryPrimaryText)
                    Text("units sold")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.luxurySecondaryText)
                }
                Spacer()
                Text("₹\(Int(trend.price))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color.luxuryDeepAccent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .frame(width: 160, height: 200)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: isTop ? accentColor.opacity(0.15) : Color.black.opacity(0.06), radius: 10, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(isTop ? accentColor.opacity(0.3) : Color.clear, lineWidth: 1)
        )
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
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.catalog.enumerated()), id: \.element.id) { index, product in
                                CatalogRow(product: product)
                                if index < viewModel.catalog.count - 1 {
                                    Divider()
                                        .background(Color.luxuryDivider)
                                        .padding(.leading, 16)
                                }
                            }
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
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

struct CatalogRow: View {
    let product: Product
    var body: some View {
        HStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.luxurySurface)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "tag")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.luxuryPrimary)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(BrandFont.body(14, weight: .medium))
                    .foregroundStyle(Color.luxuryPrimaryText)
                Text(product.category)
                    .font(BrandFont.body(11))
                    .foregroundStyle(Color.luxurySecondaryText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("₹\(Int(product.price))")
                    .font(BrandFont.body(14, weight: .semibold))
                    .foregroundStyle(Color.luxuryDeepAccent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
