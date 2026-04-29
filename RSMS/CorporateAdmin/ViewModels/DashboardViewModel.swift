import Foundation
import Combine

@MainActor
public final class DashboardViewModel: ObservableObject {
    @Published public var pendingRequests: [ProductRequest] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    // Gross Sales vs Target
    @Published public var grossSales: Double = 0
    @Published public var totalTarget: Double = 0
    @Published public var isSalesLoading = false

    // Category-wise Sales
    @Published public var categorySales: [CategorySales] = []
    @Published public var isCategoryLoading = false
    
    // Top Performing Stores
    @Published public var topPerformingStores: [StorePerformance] = []
    @Published public var isTopStoresLoading = false
    @Published public var selectedTimeRange: String = "monthly"

    public var remainingTarget: Double {
        max(0, totalTarget - grossSales)
    }

    public var achievementPercentage: Double {
        guard totalTarget > 0 else { return 0 }
        return min(1.0, grossSales / totalTarget)
    }

    nonisolated(unsafe) private let service = RequestService.shared
    nonisolated(unsafe) private let adminService = AdminService.shared

    public init() {}

    public func fetchPendingRequests() async {
        isLoading = true
        do {
            pendingRequests = try await service.fetchPendingRequests()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    public func fetchGrossSalesVsTarget() async {
        isSalesLoading = true
        do {
            let result = try await adminService.fetchGrossSalesAndTarget(timeRange: selectedTimeRange)
            grossSales = result.grossSales
            totalTarget = result.totalTarget
        } catch {
            print("DashboardViewModel: fetchGrossSalesVsTarget error:", error)
        }
        isSalesLoading = false
    }

    public func fetchCategoryWiseSales() async {
        isCategoryLoading = true
        do {
            categorySales = try await adminService.fetchCategoryWiseSales(timeRange: selectedTimeRange)
        } catch {
            print("DashboardViewModel: fetchCategoryWiseSales error:", error)
        }
        isCategoryLoading = false
    }

    public func fetchTopPerformingStores() async {
        isTopStoresLoading = true
        do {
            topPerformingStores = try await adminService.fetchTopPerformingStores(timeRange: selectedTimeRange)
        } catch {
            print("DashboardViewModel: fetchTopPerformingStores error:", error)
        }
        isTopStoresLoading = false
    }

    public func fetchDashboardData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.fetchGrossSalesVsTarget() }
            group.addTask { await self.fetchCategoryWiseSales() }
            group.addTask { await self.fetchTopPerformingStores() }
        }
    }

    public func acceptRequest(id: UUID) async {
        do {
            try await service.updateRequestStatus(id: id, status: "approved")
            await fetchPendingRequests()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func rejectRequest(id: UUID, reason: String) async {
        do {
            try await service.updateRequestStatus(id: id, status: "rejected", rejectReason: reason)
            await fetchPendingRequests()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
