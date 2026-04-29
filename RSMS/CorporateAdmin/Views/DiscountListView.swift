import SwiftUI

public struct DiscountListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = DiscountViewModel()
    @State private var showingCreateSheet = false
    @State private var showingStoreFilter = false
    @State private var couponToEdit: DiscountCoupon?
    
    public init() {}
    
    public var body: some View {
        ZStack {
            CatalogTheme.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Custom Header
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 44, height: 44)
                                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(CatalogTheme.primaryText)
                        }
                    }
                    
                    Spacer()
                    
                    Text("Discounts & Promotions")
                        .font(BrandFont.display(18, weight: .bold))
                        .foregroundColor(CatalogTheme.primaryText)
                    
                    Spacer()
                    
                    Button {
                        showingCreateSheet = true
                    } label: {
                        AppPlusIconButton(size: 44)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        // Header Stats
                        headerStatsView
                        
                        // Search and Filters
                        VStack(spacing: 16) {
                            searchBar
                            filterChipRow
                        }
                        
                        // List Content
                        if viewModel.isLoading && viewModel.coupons.isEmpty {
                            ProgressView()
                                .tint(CatalogTheme.primary)
                                .padding(.top, 40)
                        } else if viewModel.filteredCoupons.isEmpty {
                            emptyStateView
                                .padding(.top, 40)
                        } else {
                            couponListSection
                        }
                    }
                    .padding(.bottom, 32)
                }
                .refreshable {
                    await viewModel.loadData()
                }
            }
        }
        .navigationBarHidden(true)
        .task {
            await viewModel.loadData()
        }
        .sheet(isPresented: $showingCreateSheet) {
            CouponFormView(viewModel: viewModel)
        }
        .sheet(item: $couponToEdit) { coupon in
            CouponFormView(viewModel: viewModel, coupon: coupon)
        }
    }
    
    private var headerStatsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                statCard(title: "Total Coupons", value: "\(viewModel.stats.total)", color: CatalogTheme.primary)
                statCard(title: "Active", value: "\(viewModel.stats.active)", color: .green)
                statCard(title: "Expired", value: "\(viewModel.stats.expired)", color: .orange)
                statCard(title: "Total Discount", value: formatShortCurrency(viewModel.stats.totalDiscount), color: CatalogTheme.deepAccent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
    }
    
    private func statCard(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(BrandFont.body(12, weight: .medium))
                .foregroundColor(CatalogTheme.secondaryText)
            
            Text(value)
                .font(BrandFont.display(22, weight: .bold))
                .foregroundColor(color)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .frame(minWidth: 130, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
    }
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(CatalogTheme.mutedText)
            TextField("Search code or description...", text: $viewModel.searchQuery)
                .font(BrandFont.body(15))
        }
        .padding(12)
        .background(CatalogTheme.surface.opacity(0.5))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }
    
    private var filterChipRow: some View {
        HStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(DiscountViewModel.CouponFilter.allCases, id: \.self) { filter in
                        filterChip(filter: filter)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Button {
                showingStoreFilter = true
            } label: {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .font(.system(size: 20))
                    .foregroundColor(viewModel.selectedStoreFilter != nil ? CatalogTheme.primary : CatalogTheme.secondaryText)
            }
            .padding(.trailing, 20)
        }
    }
    
    private func filterChip(filter: DiscountViewModel.CouponFilter) -> some View {
        let isSelected = viewModel.selectedFilter == filter
        return Button {
            viewModel.selectedFilter = filter
        } label: {
            Text(filter.rawValue)
                .font(BrandFont.body(13, weight: isSelected ? .bold : .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? CatalogTheme.primary : Color.clear)
                .foregroundColor(isSelected ? .white : CatalogTheme.secondaryText)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? Color.clear : CatalogTheme.surface, lineWidth: 1)
                )
        }
    }
    
    private var couponListSection: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.filteredCoupons) { coupon in
                ZStack {
                    NavigationLink(destination: CouponDetailView(coupon: coupon)) {
                        EmptyView()
                    }
                    .opacity(0)
                    
                    couponRow(coupon: coupon)
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        Task { await viewModel.deleteCoupon(coupon) }
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    
                    Button {
                        couponToEdit = coupon
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
        }
        .padding(.horizontal, 20)
    }
    
    private func couponRow(coupon: DiscountCoupon) -> some View {
        let isExpired = coupon.validUntil != nil && coupon.validUntil! <= Date()
        
        return HStack(spacing: 14) {
            // Leading Badge
            Text(coupon.code)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isExpired ? CatalogTheme.mutedText : CatalogTheme.primary)
                .clipShape(Capsule())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(coupon.description ?? coupon.code)
                    .font(BrandFont.body(15, weight: .bold))
                    .foregroundColor(CatalogTheme.primaryText)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    Text(coupon.discountType == .percentage ? "\(Int(coupon.discountValue))% off" : "₹\(Int(coupon.discountValue)) flat")
                    Text("·")
                    if let expiry = coupon.validUntil {
                        Text("Valid until \(expiry, style: .date)")
                    } else {
                        Text("No expiry")
                    }
                }
                .font(BrandFont.body(12))
                .foregroundColor(CatalogTheme.secondaryText)
                
                Text("\(0) stores · Used \(coupon.usageCount)/\(coupon.usageLimit.map { "\($0)" } ?? "∞") times")
                    .font(BrandFont.body(12))
                    .foregroundColor(CatalogTheme.mutedText)
            }
            .opacity(isExpired ? 0.6 : 1.0)
            
            Spacer()
            
            if isExpired {
                Text("Expired")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange)
                    .clipShape(Capsule())
            } else {
                Toggle("", isOn: Binding(
                    get: { coupon.isActive },
                    set: { _ in
                        Task { await viewModel.toggleCouponStatus(coupon: coupon) }
                    }
                ))
                .labelsHidden()
                .tint(CatalogTheme.primary)
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tag.slash")
                .font(.system(size: 64))
                .foregroundColor(CatalogTheme.mutedText)
            
            Text("No coupons yet")
                .font(BrandFont.display(20, weight: .bold))
                .foregroundColor(CatalogTheme.primaryText)
            
            Text("Create your first discount to get started")
                .font(BrandFont.body(14))
                .foregroundColor(CatalogTheme.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showingCreateSheet = true
            } label: {
                Text("Create Coupon")
                    .font(BrandFont.body(15, weight: .semibold))
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(CatalogTheme.primary)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 8)
            
            Spacer()
        }
    }
}

