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
                NavigationLink(destination: CouponDetailView(coupon: coupon)) {
                    couponRow(coupon: coupon)
                }
                .buttonStyle(PlainButtonStyle())
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
        let isInactive = !coupon.isActive
        let ticketColor = Color(red: 1.0, green: 0.94, blue: 0.96) // Soft Pink
        
        return ZStack(alignment: .topTrailing) {
            HStack(spacing: 0) {
                // Barcode Section
                VStack {
                    BarcodeView()
                        .frame(width: 40, height: 80)
                }
                .frame(width: 80)
                
                // Dashed Divider
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 2)
                    .overlay(
                        VStack(spacing: 5) {
                            ForEach(0..<12) { _ in
                                Rectangle()
                                    .fill(Color.black.opacity(0.2))
                                    .frame(width: 1.5, height: 4)
                            }
                        }
                    )
                
                // Content Section
                VStack(spacing: 6) {
                    Text(coupon.code)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(CatalogTheme.primary.opacity(0.8))
                        .tracking(1.5)
                    
                    Text(coupon.description ?? "DISCOUNT")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    
                    VStack(spacing: 4) {
                        Text(coupon.discountType == .percentage ? "\(Int(coupon.discountValue))% OFF" : "₹\(Int(coupon.discountValue)) FLAT")
                            .font(.system(size: 13, weight: .black))
                            .foregroundColor(CatalogTheme.primary)
                        
                        if let expiry = coupon.validUntil {
                            VStack(spacing: 1) {
                                Text("Valid Until")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundColor(.gray)
                                Text(expiry.formatted(date: .long, time: .omitted))
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.black)
                            }
                            .padding(.top, 2)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
            }
            .frame(height: 140)
            .frame(maxWidth: .infinity)
            .background(
                TicketShape(notchOffset: 80)
                    .fill(ticketColor)
            )
            .overlay(
                TicketShape(notchOffset: 80)
                    .stroke(Color.black.opacity(0.6), lineWidth: 1.2)
            )
            .opacity((isExpired || isInactive) ? 0.5 : 1.0)
            .grayscale(isInactive ? 0.3 : 0)
            .padding(.vertical, 8)
            
            // Toggle & Actions
            HStack(spacing: 12) {
                if !isExpired {
                    Toggle("", isOn: Binding(
                        get: { coupon.isActive },
                        set: { newValue in
                            viewModel.toggleCouponStatus(coupon: coupon, targetStatus: newValue)
                        }
                    ))
                    .labelsHidden()
                    .tint(CatalogTheme.primary)
                    .scaleEffect(0.7)
                } else {
                    Text("EXPIRED")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.orange)
                        .clipShape(Capsule())
                }
            }
            .padding(.trailing, 10)
            .padding(.top, 14)
        }
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

// MARK: - Ticket UI Components

struct TicketShape: Shape {
    var notchOffset: CGFloat
    var notchRadius: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Start top left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        
        // Top edge with notch
        path.addLine(to: CGPoint(x: notchOffset - notchRadius, y: rect.minY))
        path.addArc(center: CGPoint(x: notchOffset, y: rect.minY),
                    radius: notchRadius,
                    startAngle: .degrees(180),
                    endAngle: .degrees(0),
                    clockwise: true)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        
        // Right edge with notch
        path.addArc(center: CGPoint(x: rect.maxX, y: rect.midY),
                    radius: notchRadius,
                    startAngle: .degrees(270),
                    endAngle: .degrees(90),
                    clockwise: true)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        
        // Bottom edge with notch
        path.addLine(to: CGPoint(x: notchOffset + notchRadius, y: rect.maxY))
        path.addArc(center: CGPoint(x: notchOffset, y: rect.maxY),
                    radius: notchRadius,
                    startAngle: .degrees(0),
                    endAngle: .degrees(180),
                    clockwise: true)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        
        // Left edge with notch
        path.addArc(center: CGPoint(x: rect.minX, y: rect.midY),
                    radius: notchRadius,
                    startAngle: .degrees(90),
                    endAngle: .degrees(270),
                    clockwise: true)
        path.closeSubpath()
        
        return path
    }
}

struct BarcodeView: View {
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<15) { _ in
                Rectangle()
                    .fill(Color.black.opacity(0.8))
                    .frame(width: CGFloat.random(in: 1...3.5))
            }
        }
    }
}

