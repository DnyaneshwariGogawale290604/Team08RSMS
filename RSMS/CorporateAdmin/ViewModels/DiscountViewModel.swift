import Foundation
import Combine
import SwiftUI

@MainActor
public final class DiscountViewModel: ObservableObject {
    @Published var coupons: [DiscountCoupon] = []
    @Published var filteredCoupons: [DiscountCoupon] = []
    @Published var isLoading = false
    @Published var stats: (total: Int, active: Int, expired: Int, totalDiscount: Double) = (0, 0, 0, 0)
    
    @Published var searchQuery = ""
    @Published var selectedFilter: CouponFilter = .all
    @Published var selectedStoreFilter: UUID? = nil
    
    @Published var stores: [Store] = []
    @Published var isStoresLoading = false
    
    private let service = DiscountService.shared
    private let storeService = StoreService.shared
    private var cancellables = Set<AnyCancellable>()
    
    public enum CouponFilter: String, CaseIterable {
        case all = "All"
        case active = "Active"
        case inactive = "Inactive"
        case expired = "Expired"
    }
    
    public init() {
        setupFiltering()
    }
    
    private func setupFiltering() {
        Publishers.CombineLatest3($coupons, $searchQuery, $selectedFilter)
            .map { coupons, query, filter in
                coupons.filter { coupon in
                    let matchesQuery = query.isEmpty || 
                        coupon.code.localizedCaseInsensitiveContains(query) || 
                        (coupon.description?.localizedCaseInsensitiveContains(query) ?? false)
                    
                    let matchesFilter: Bool
                    switch filter {
                    case .all: matchesFilter = true
                    case .active: matchesFilter = coupon.isActive && (coupon.validUntil == nil || coupon.validUntil! > Date())
                    case .inactive: matchesFilter = !coupon.isActive
                    case .expired: matchesFilter = coupon.validUntil != nil && coupon.validUntil! <= Date()
                    }
                    
                    return matchesQuery && matchesFilter
                }
            }
            .assign(to: &$filteredCoupons)
    }
    
    public func loadData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            async let couponsTask = service.fetchCoupons()
            async let statsTask = service.fetchUsageStats()
            async let storesTask = storeService.fetchStores()
            
            self.coupons = try await couponsTask
            self.stats = try await statsTask
            self.stores = try await storesTask
        } catch {
            print("DiscountViewModel Error: \(error)")
        }
    }
    
    public func toggleCouponStatus(coupon: DiscountCoupon) async {
        guard let index = coupons.firstIndex(where: { $0.id == coupon.id }) else { return }
        let newStatus = !coupon.isActive
        
        // Optimistic update
        coupons[index].isActive = newStatus
        
        do {
            try await service.updateCouponStatus(id: coupon.id, isActive: newStatus)
            // Refresh stats
            stats = try await service.fetchUsageStats()
        } catch {
            // Revert on failure
            coupons[index].isActive = !newStatus
            print("DiscountViewModel Toggle Error: \(error)")
        }
    }
    
    public func deleteCoupon(_ coupon: DiscountCoupon) async {
        do {
            let useSoftDelete = coupon.usageCount > 0
            try await service.deleteCoupon(id: coupon.id, softDelete: useSoftDelete)
            await loadData()
        } catch {
            print("DiscountViewModel Delete Error: \(error)")
        }
    }
}
