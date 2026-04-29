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
        isStoresLoading = true
        defer { 
            isLoading = false
            isStoresLoading = false
        }
        
        // Fetch stores independently to ensure they load even if coupons fail
        do {
            self.stores = try await storeService.fetchStores()
        } catch {
            print("DiscountViewModel fetchStores Error: \(error)")
        }
        
        do {
            self.coupons = try await service.fetchCoupons()
        } catch {
            print("DiscountViewModel fetchCoupons Error: \(error)")
        }
        
        do {
            self.stats = try await service.fetchUsageStats()
        } catch {
            print("DiscountViewModel fetchStats Error: \(error)")
        }
    }
    
    public func toggleCouponStatus(coupon: DiscountCoupon, targetStatus: Bool) {
        guard let index = coupons.firstIndex(where: { $0.id == coupon.id }) else { return }
        
        // 1. Synchronous update for immediate UI response
        coupons[index].isActive = targetStatus
        
        // 2. Asynchronous network call
        Task {
            do {
                try await service.updateCouponStatus(id: coupon.id, isActive: targetStatus)
            } catch {
                // Revert on failure
                await MainActor.run {
                    if let revertIndex = self.coupons.firstIndex(where: { $0.id == coupon.id }) {
                        self.coupons[revertIndex].isActive = !targetStatus
                    }
                }
                print("DiscountViewModel Toggle Error: \(error)")
            }
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
