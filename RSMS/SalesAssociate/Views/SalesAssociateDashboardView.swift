import SwiftUI

struct SalesAssociateDashboardView: View {
    @StateObject private var viewModel = SalesAssociateViewModel()
    // Observe the shared cache so the rating card updates the moment a new
    // rating is submitted — without any additional Supabase fetch.
    @ObservedObject private var ratingCache = RatingCache.shared
    @State private var showCatalog = false
    @State private var catalogSearch = ""

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandOffWhite.ignoresSafeArea()

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
                        .foregroundStyle(Color.brandWarmBlack)
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
                .foregroundStyle(Color.brandWarmGrey)
            Text("Sales Associate")
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(Color.brandWarmBlack)
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
                            .foregroundStyle(Color.brandWarmBlack)
                        Text("/ 5")
                            .font(BrandFont.body(16))
                            .foregroundStyle(Color.brandWarmGrey)
                    }
                    Text(ratingCache.ratingsCount == 1 ? "1 review" : "\(ratingCache.ratingsCount) reviews")
                        .font(BrandFont.body(12))
                        .foregroundStyle(Color.brandWarmGrey)
                }
                Spacer()
                HStack(spacing: 5) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: Double(star) <= ratingCache.averageRating ? "star.fill" : "star")
                            .foregroundStyle(Double(star) <= ratingCache.averageRating ? Color.init(hex: "#C8913A") ?? .yellow : Color.brandPebble)
                            .font(.title3)
                    }
                }
            }
            .padding(16)
            .background(Color.brandLinen)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandPebble, lineWidth: 0.5))
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
                    .foregroundStyle(Color.brandWarmGrey)
                Spacer()
                Button {
                    withAnimation { showCatalog.toggle() }
                    if showCatalog && viewModel.catalog.isEmpty {
                        Task { await viewModel.fetchCatalog() }
                    }
                } label: {
                    Text(showCatalog ? "Hide" : "Show all")
                        .font(BrandFont.body(13))
                        .foregroundStyle(Color.brandWarmBlack)
                }
            }
            .padding(.horizontal, 16)

            if showCatalog {
                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color.brandWarmGrey)
                            .font(.system(size: 14))
                        TextField("Search products...", text: $catalogSearch)
                            .font(BrandFont.body(14))
                            .foregroundStyle(Color.brandWarmBlack)
                            .onChange(of: catalogSearch) { newSearch in
                                Task { await viewModel.fetchCatalog(search: newSearch) }
                            }
                    }
                    .padding(16)
                    .background(Color.brandLinen)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandPebble, lineWidth: 0.5))
                    .padding(.horizontal, 16)

                    if viewModel.catalog.isEmpty {
                        emptyStateCard(icon: "tag.slash", text: "No products matched.")
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(viewModel.catalog.enumerated()), id: \.element.id) { index, product in
                                CatalogRow(product: product)
                                if index < viewModel.catalog.count - 1 {
                                    Divider()
                                        .background(Color.brandPebble)
                                        .padding(.leading, 16)
                                }
                            }
                        }
                        .background(Color.brandLinen)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandPebble, lineWidth: 0.5))
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
                .foregroundStyle(Color.brandPebble)
            Text(text)
                .font(BrandFont.body(13))
                .foregroundStyle(Color.brandWarmGrey)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandLinen)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandPebble, lineWidth: 0.5))
        .padding(.horizontal, 16)
    }

    private func sectionHeader(title: String) -> some View {
        Text(title)
            .font(.system(size: 11, weight: .semibold))
            .kerning(1.2)
            .foregroundStyle(Color.brandWarmGrey)
            .padding(.horizontal, 16)
    }

    private func statCard(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .kerning(1.2)
                .foregroundStyle(Color.brandWarmGrey)
            Text(value)
                .font(BrandFont.display(24))
                .foregroundStyle(Color.brandWarmBlack)
            Text(subtitle)
                .font(BrandFont.body(12))
                .foregroundStyle(Color.brandWarmGrey)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.brandLinen)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.brandPebble, lineWidth: 0.5)
        )
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
                .fill(Color.brandOffWhite)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "tag")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.brandWarmGrey)
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(BrandFont.body(14, weight: .medium))
                    .foregroundStyle(Color.brandWarmBlack)
                Text(product.category)
                    .font(BrandFont.body(11))
                    .foregroundStyle(Color.brandWarmGrey)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("₹\(Int(product.price))")
                    .font(BrandFont.body(14, weight: .semibold))
                    .foregroundStyle(Color.brandWarmBlack)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

