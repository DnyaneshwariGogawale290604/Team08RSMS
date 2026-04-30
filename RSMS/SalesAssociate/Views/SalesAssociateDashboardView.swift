import SwiftUI

struct SalesAssociateDashboardView: View {
    @ObservedObject private var sessionViewModel: SessionViewModel
    @StateObject private var viewModel = SalesAssociateViewModel()
    @ObservedObject private var ratingCache = RatingCache.shared

    @State private var showCatalog = false
    @State private var catalogSearch = ""
    @State private var animatedRevenue: Double = 0
    @State private var animatedOrders: Double = 0
    @State private var sparklineProgress: CGFloat = 0

    init(sessionViewModel: SessionViewModel) {
        self.sessionViewModel = sessionViewModel
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BoutiqueTheme.background.ignoresSafeArea()

                if viewModel.isLoading && viewModel.recentOrders.isEmpty {
                    LoadingView(message: "Loading dashboard...")
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 24) {
                            dashboardHeader
                            heroBanner
                            ratingSection
                            trendingSection
                            catalogSection
                        }
                        .padding(.horizontal, 20)
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
                ToolbarItem(placement: .topBarTrailing) {
                    SalesAssociateProfileButton(sessionViewModel: sessionViewModel)
                }
            }
            .task {
                await viewModel.refresh()
                runDashboardAnimations()
            }
            .onAppear {
                Task { await viewModel.refresh() }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("RefreshSalesAssociateDashboard"))) { _ in
                Task { await viewModel.refresh() }
            }
            .onChange(of: viewModel.todaySalesAmount) { _ in
                runDashboardAnimations()
            }
            .onChange(of: viewModel.todayOrderCount) { _ in
                runDashboardAnimations()
            }
        }
    }

    private var dashboardHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Sales Dashboard")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(BoutiqueTheme.primaryText)

            Text(todayDateText)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(BoutiqueTheme.mutedText)
        }
    }

    private var heroBanner: some View {
        VStack(alignment: .leading, spacing: 18) {
            quietSectionLabel("Overview")

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    AnimatedNumberText(
                        value: animatedRevenue,
                        format: { currency($0) },
                        font: .system(size: 34, weight: .bold)
                    )
                    .foregroundStyle(BoutiqueTheme.deepAccent)

                    Text("Revenue")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(BoutiqueTheme.secondaryText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    AnimatedNumberText(
                        value: animatedOrders,
                        format: { "\(Int($0.rounded()))" },
                        font: .system(size: 34, weight: .bold)
                    )
                    .foregroundStyle(BoutiqueTheme.primaryText)

                    Text("Total Orders")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(BoutiqueTheme.secondaryText)
                }
            }

                SparklineView(values: sevenDayRevenue, progress: sparklineProgress)
                    .frame(height: 56)

                HStack {
                    ForEach(sevenDayLabels, id: \.self) { label in
                        Text(label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(BoutiqueTheme.mutedText)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(20)
            .background(
                LinearGradient(
                    colors: [Color.white, BoutiqueTheme.surface.opacity(0.65)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(BoutiqueTheme.divider, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }

    private var ratingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            quietSectionLabel("My Rating")

            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(String(format: "%.1f", ratingCache.averageRating))
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(BoutiqueTheme.primaryText)

                        HStack(spacing: 5) {
                            ForEach(1...5, id: \.self) { star in
                                Image(systemName: Double(star) <= ratingCache.averageRating ? "star.fill" : "star")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(BoutiqueTheme.deepAccent)
                            }
                        }
                    }

                    Spacer()

                    Text(ratingCache.ratingsCount == 1 ? "1 review" : "\(ratingCache.ratingsCount) reviews")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(BoutiqueTheme.primary)
                        .clipShape(Capsule())
                }
            }
            .padding(20)
            .background(Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(BoutiqueTheme.divider, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private var trendingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            quietSectionLabel("Trending Products")

            if viewModel.trendingProducts.isEmpty {
                emptyStateCard(icon: "arrow.up.right", text: "No trend data yet — complete some orders to see trending products.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(viewModel.trendingProducts.enumerated()), id: \.element.id) { index, trend in
                            TrendingCompactCard(trend: trend, rank: index + 1)
                        }
                    }
                    .padding(.vertical, 16)
                }
            }
        }
    }

    private var catalogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                quietSectionLabel("Product Catalog")

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showCatalog.toggle()
                    }
                    if showCatalog && viewModel.catalog.isEmpty {
                        Task { await viewModel.fetchCatalog() }
                    }
                } label: {
                    Image(systemName: showCatalog ? "chevron.up" : "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(BoutiqueTheme.primary)
                        .frame(width: 32, height: 32)
                        .background(BoutiqueTheme.surface.opacity(0.75))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            if showCatalog {
                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(BoutiqueTheme.primary)
                            .font(.system(size: 14, weight: .medium))

                        TextField(
                            "",
                            text: $catalogSearch,
                            prompt: Text("Search products...").foregroundStyle(BoutiqueTheme.secondaryText)
                        )
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(BoutiqueTheme.primaryText)
                        .onChange(of: catalogSearch) { newSearch in
                            Task { await viewModel.fetchCatalog(search: newSearch) }
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 50)
                    .background(Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 25, style: .continuous)
                            .stroke(BoutiqueTheme.divider, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))

                    if viewModel.catalog.isEmpty {
                        emptyStateCard(icon: "tag.slash", text: "No products matched.")
                    } else {
                        LazyVGrid(
                            columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ],
                            spacing: 16
                        ) {
                            ForEach(viewModel.catalog) { product in
                                AssociateProductCard(product: product)
                            }
                        }
                    }
                }
            }
        }
    }

    private var todayDateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter.string(from: Date())
    }

    private var sevenDayRevenue: [Double] {
        let calendar = Calendar.current
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let grouped = Dictionary(grouping: viewModel.recentOrders) { order -> Date in
            guard let createdAt = order.createdAt else { return calendar.startOfDay(for: Date()) }
            let parsed = formatter.date(from: createdAt) ?? ISO8601DateFormatter().date(from: createdAt) ?? Date()
            return calendar.startOfDay(for: parsed)
        }

        return (0..<7).map { offset in
            let day = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -(6 - offset), to: Date()) ?? Date())
            let amount = grouped[day, default: []].reduce(0) { $0 + $1.totalAmount }
            return amount
        }
    }

    private var sevenDayLabels: [String] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "E"

        return (0..<7).map { offset in
            let date = calendar.date(byAdding: .day, value: -(6 - offset), to: Date()) ?? Date()
            return formatter.string(from: date)
        }
    }

    private var sparklineMaxValue: Double {
        sevenDayRevenue.max() ?? 0
    }

    private var sparklineMinValue: Double {
        sevenDayRevenue.min() ?? 0
    }

    private func quietSectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .bold, design: .serif))
            .foregroundColor(CatalogTheme.primaryText)
    }

    private func emptyStateCard(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(BoutiqueTheme.mutedText)

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(BoutiqueTheme.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(BoutiqueTheme.divider, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func currency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return "₹\(formatter.string(from: NSNumber(value: value)) ?? "0")"
    }

    private func shortCurrency(_ value: Double) -> String {
        if value >= 100_000 {
            return String(format: "₹%.1fL", value / 100_000)
        }
        if value >= 1_000 {
            return String(format: "₹%.0fK", value / 1_000)
        }
        return "₹\(Int(value.rounded()))"
    }

    private func runDashboardAnimations() {
        animatedRevenue = 0
        animatedOrders = 0
        sparklineProgress = 0

        withAnimation(.easeOut(duration: 0.6)) {
            animatedRevenue = viewModel.todaySalesAmount
            animatedOrders = Double(viewModel.todayOrderCount)
        }

        withAnimation(.easeOut(duration: 0.8)) {
            sparklineProgress = 1
        }
    }
}

private struct AnimatedNumberText: View {
    let value: Double
    let format: (Double) -> String
    let font: Font

    var body: some View {
        Text(format(value))
            .font(font)
            .contentTransition(.numericText(value: value))
            .animation(.easeOut(duration: 0.6), value: value)
    }
}

private struct SparklineView: View {
    let values: [Double]
    let progress: CGFloat

    var body: some View {
        GeometryReader { geometry in
            let path = sparklinePath(in: geometry.size)

            ZStack(alignment: .bottomLeading) {
                path
                    .trim(from: 0, to: progress)
                    .stroke(
                        BoutiqueTheme.deepAccent,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                    )

                LinearGradient(
                    colors: [BoutiqueTheme.deepAccent.opacity(0.2), BoutiqueTheme.deepAccent.opacity(0.02)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .mask(
                    path
                        .trim(from: 0, to: progress)
                        .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                )
            }
        }
    }

    private func sparklinePath(in size: CGSize) -> Path {
        let safeValues = values.isEmpty ? [0, 0, 0, 0, 0, 0, 0] : values
        let maxValue = max(safeValues.max() ?? 1, 1)
        let minValue = safeValues.min() ?? 0
        let range = max(maxValue - minValue, 1)

        return Path { path in
            for index in safeValues.indices {
                let x = size.width * CGFloat(index) / CGFloat(max(safeValues.count - 1, 1))
                let normalized = (safeValues[index] - minValue) / range
                let y = size.height - (size.height * CGFloat(normalized))

                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }
}

private struct PressableCard<Content: View>: View {
    let content: Content
    @State private var isPressed = false

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .scaleEffect(isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: isPressed)
            .onLongPressGesture(minimumDuration: 0.01, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
    }
}

private struct TrendingCompactCard: View {
    let trend: TrendingProduct
    let rank: Int

    var body: some View {
        PressableCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    // Small Thumbnail
                    ZStack {
                        BoutiqueTheme.surface
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        
                        if let imageUrl = trend.imageUrl, let url = URL(string: imageUrl) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                default:
                                    Image(systemName: "photo")
                                        .font(.system(size: 16))
                                        .foregroundStyle(BoutiqueTheme.divider)
                                }
                            }
                        } else {
                            Image(systemName: "bag.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(BoutiqueTheme.primary.opacity(0.3))
                        }
                    }
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .clipped()
                    
                    // Product Info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(rank == 2 ? trend.name.replacingOccurrences(of: " Men", with: "\nMen") : trend.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(BoutiqueTheme.primaryText)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                        
                        Text(rank == 2 ? trend.category.replacingOccurrences(of: " Men", with: "\nMen") : (trend.category.isEmpty ? "Product" : trend.category))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(BoutiqueTheme.secondaryText)
                            .textCase(.uppercase)
                            .kerning(1)
                    }
                }
                
                // Bottom row: Stats and Price
                HStack(alignment: .center) {
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 9))
                        Text("\(trend.soldCount) sold")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(BoutiqueTheme.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(BoutiqueTheme.primary.opacity(0.1))
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    Text("₹\(Int(trend.price))")
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundStyle(BoutiqueTheme.deepAccent)
                }
            }
            .padding(16)
            .frame(width: 230, height: 180)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
            .overlay(alignment: .topTrailing) {
                Text("#\(rank)")
                    .font(.system(size: 9, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(BoutiqueTheme.primary)
                    .clipShape(Capsule())
                    .padding(12)
            }
        }
    }
}

struct AssociateProductCard: View {
    let product: Product
    @State private var isPressed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack {
                BoutiqueTheme.surface

                if let imageUrl = product.displayImageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                                .foregroundStyle(BoutiqueTheme.divider)
                        }
                    }
                } else {
                    Image(systemName: "tag")
                        .font(.system(size: 24))
                        .foregroundStyle(BoutiqueTheme.primary.opacity(0.5))
                }
            }
            .frame(height: 116)
            .frame(maxWidth: .infinity)
            .clipped()

            VStack(alignment: .leading, spacing: 8) {
                Text(product.name)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(BoutiqueTheme.primaryText)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                    .frame(height: 58, alignment: .topLeading)

                Text("₹\(Int(product.price))")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(BoutiqueTheme.deepAccent)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 220)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isPressed ? BoutiqueTheme.primary : BoutiqueTheme.divider, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .scaleEffect(isPressed ? 0.97 : 1)
        .animation(.easeOut(duration: 0.15), value: isPressed)
        .onLongPressGesture(minimumDuration: 0.01, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
    }
}
