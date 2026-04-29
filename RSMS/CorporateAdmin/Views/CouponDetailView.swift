import SwiftUI
import Charts

struct CouponDetailView: View {
    @State var coupon: DiscountCoupon
    @StateObject private var viewModel = DiscountViewModel()
    @State private var usages: [DiscountUsage] = []
    @State private var stores: [Store] = []
    @State private var isLoading = false
    @State private var showingEditSheet = false
    
    // For pagination
    @State private var offset = 0
    @State private var canLoadMore = true
    
    public var body: some View {
        ZStack {
            CatalogTheme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 32) {
                    summaryCard
                    
                    if !usages.isEmpty {
                        usageChartSection
                    }
                    
                    storesSection
                    
                    usageHistorySection
                }
                .padding(20)
            }
        }
        .navigationTitle(coupon.code)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
                .font(.body.bold())
                .foregroundColor(CatalogTheme.primary)
            }
        }
        .task {
            await loadInitialData()
        }
        .sheet(isPresented: $showingEditSheet) {
            CouponFormView(viewModel: viewModel, coupon: coupon)
                .onDisappear {
                    Task { await refreshCoupon() }
                }
        }
    }
    
    private func refreshCoupon() async {
        do {
            self.coupon = try await DiscountService.shared.fetchCoupon(id: coupon.id)
            await loadInitialData()
        } catch {
            print("Error refreshing coupon: \(error)")
        }
    }
    
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(coupon.code)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(CatalogTheme.primaryText)
                    
                    if let desc = coupon.description {
                        Text(desc)
                            .font(BrandFont.body(16))
                            .foregroundColor(CatalogTheme.secondaryText)
                    }
                }
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(coupon.discountType == .percentage ? "\(Int(coupon.discountValue))%" : "₹\(Int(coupon.discountValue))")
                        .font(BrandFont.display(28, weight: .bold))
                        .foregroundColor(CatalogTheme.primary)
                    Text(coupon.discountType == .percentage ? "PERCENTAGE" : "FLAT AMOUNT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(CatalogTheme.mutedText)
                }
            }
            
            Divider()
            
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Usage Limit")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(CatalogTheme.mutedText)
                    Text(coupon.usageLimit.map { "\($0)" } ?? "Unlimited")
                        .font(BrandFont.body(15, weight: .bold))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Usage Count")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(CatalogTheme.mutedText)
                    Text("\(coupon.usageCount)")
                        .font(BrandFont.body(15, weight: .bold))
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Status")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(CatalogTheme.mutedText)
                    Text(coupon.isActive ? "Active" : "Inactive")
                        .font(BrandFont.body(15, weight: .bold))
                        .foregroundColor(coupon.isActive ? .green : .red)
                }
            }
            
            if let limit = coupon.usageLimit, limit > 0 {
                VStack(alignment: .leading, spacing: 8) {
                    let progress = Double(coupon.usageCount) / Double(limit)
                    ProgressView(value: min(progress, 1.0))
                        .tint(CatalogTheme.primary)
                    
                    Text("\(Int(progress * 100))% of limit used")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(CatalogTheme.secondaryText)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(20)
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
    
    private var usageChartSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Usage (Last 30 days)")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(CatalogTheme.secondaryText)
                .padding(.leading, 4)
            
            VStack {
                Chart {
                    ForEach(dailyUsageData) { item in
                        BarMark(
                            x: .value("Day", item.date, unit: .day),
                            y: .value("Count", item.count)
                        )
                        .foregroundStyle(CatalogTheme.primary.gradient)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
                        AxisValueLabel(format: .dateTime.day().month())
                    }
                }
                .frame(height: 180)
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(20)
            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        }
    }
    
    private var storesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Visible in stores")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(CatalogTheme.secondaryText)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                if stores.isEmpty {
                    VStack {
                        Text("No stores assigned")
                            .font(BrandFont.body(14))
                            .foregroundColor(CatalogTheme.mutedText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 80)
                } else {
                    ForEach(stores) { store in
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(CatalogTheme.primary)
                            Text(store.name)
                                .font(BrandFont.body(15, weight: .medium))
                            Spacer()
                            Text(store.location)
                                .font(BrandFont.body(12))
                                .foregroundColor(CatalogTheme.secondaryText)
                        }
                        .padding(.vertical, 12)
                        
                        if store.id != stores.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(Color.white)
            .cornerRadius(16)
        }
    }
    
    private var usageHistorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Usage history")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(CatalogTheme.secondaryText)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                if usages.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 32))
                        Text("No usages yet")
                            .font(BrandFont.body(14, weight: .bold))
                    }
                    .foregroundColor(CatalogTheme.mutedText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                } else {
                    ForEach(usages) { usage in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Order #\(usage.orderId.uuidString.prefix(8))")
                                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                                Spacer()
                                Text("₹\(Int(usage.discountAmount)) off")
                                    .font(BrandFont.body(14, weight: .bold))
                                    .foregroundColor(CatalogTheme.primary)
                            }
                            
                            HStack {
                                Text("\(usage.storeName ?? "Store") · \(usage.associateName ?? "Associate")")
                                    .font(BrandFont.body(12))
                                    .foregroundColor(CatalogTheme.secondaryText)
                                Spacer()
                                Text(usage.appliedAt, style: .date)
                                    .font(BrandFont.body(11))
                                    .foregroundColor(CatalogTheme.mutedText)
                            }
                        }
                        .padding(.vertical, 14)
                        
                        if usage.id != usages.last?.id {
                            Divider()
                        }
                    }
                    
                    if canLoadMore {
                        Button {
                            Task { await loadMoreUsages() }
                        } label: {
                            Text("Load More")
                                .font(BrandFont.body(13, weight: .bold))
                                .foregroundColor(CatalogTheme.primary)
                                .padding(.vertical, 16)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(Color.white)
            .cornerRadius(16)
        }
    }
    
    private func loadInitialData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let storesIdsTask = DiscountService.shared.fetchCouponStores(couponId: coupon.id)
            async let usagesTask = DiscountService.shared.fetchCouponUsages(couponId: coupon.id, limit: 20, offset: 0)
            
            let storeIds = try await storesIdsTask
            // Fetch actual store objects
            let allStores = try await StoreService.shared.fetchStores()
            self.stores = allStores.filter { storeIds.contains($0.id) }
            
            self.usages = try await usagesTask
            self.canLoadMore = usages.count == 20
        } catch {
            print("Error loading coupon details: \(error)")
        }
    }
    
    private func loadMoreUsages() async {
        offset += 20
        do {
            let moreUsages = try await DiscountService.shared.fetchCouponUsages(couponId: coupon.id, limit: 20, offset: offset)
            self.usages.append(contentsOf: moreUsages)
            self.canLoadMore = moreUsages.count == 20
        } catch {
            print("Error loading more usages: \(error)")
        }
    }
    
    // Mock daily usage data for chart
    private var dailyUsageData: [UsagePoint] {
        // In a real app, this would be computed from usages or fetched from a dedicated endpoint
        let calendar = Calendar.current
        let now = Date()
        return (0..<30).map { dayOffset in
            let date = calendar.date(byAdding: .day, value: -dayOffset, to: now)!
            // Find count in actual usages for this day
            let count = usages.filter { calendar.isDate($0.appliedAt, inSameDayAs: date) }.count
            return UsagePoint(date: date, count: count)
        }.reversed()
    }
    
    struct UsagePoint: Identifiable {
        let id = UUID()
        let date: Date
        let count: Int
    }
}
