import Foundation
import SwiftUI
import Combine

@MainActor
public class BoutiqueDashboardViewModel: ObservableObject {
    @Published public var summary: DashboardSummary?
    @Published public var activeAlerts: [InventoryProduct] = []

    @Published public var weeklyRevenue: [DailySalesData] = []
    @Published public var topProducts: [ProductSalesData] = []
    @Published public var staffPerformance: [StaffPerformanceData] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    public init() {}

    public func loadDashboardData() {
        guard !isLoading else { return }
        Task { await loadDashboardDataAsync() }
    }

    public func loadDashboardDataAsync() async {
        isLoading = true
        errorMessage = nil

        var todayRevenue: Double = 0
        var targetRevenue: Double = 1_500_000
        var lowStockItems: [InventoryProduct] = []
        var orderCount = 0
        var avgOrderValue: Double = 0

        // MARK: Store resolution
        var storeId: UUID? = nil
        do {
            if let store = try await DataService.shared.fetchCurrentStore() {
                storeId = store.id
                targetRevenue = store.salesTarget ?? 1_500_000
            } else if let store = try await DataService.shared.fetchStores().first {
                storeId = store.id
                targetRevenue = store.salesTarget ?? 1_500_000
            }
        } catch { print("Dashboard/Store: \(error)") }

        // MARK: Sales Orders
        var allSales: [SalesOrder] = []
        do {
            allSales = try await DataService.shared.fetchSales(storeId: storeId)
            let todaySales = allSales.filter { Calendar.current.isDateInToday($0.createdAt) }
            todayRevenue = todaySales.reduce(0) { $0 + $1.totalAmount }
            orderCount = todaySales.count
            avgOrderValue = todaySales.isEmpty ? 0 : todayRevenue / Double(todaySales.count)
        } catch { print("Dashboard/Sales: \(error)") }

        // MARK: Weekly Revenue (last 7 days)
        weeklyRevenue = computeWeekly(from: allSales)

        // MARK: Products + Order Items
        var productLookup: [UUID: Product] = [:]
        do {
            let products = try await DataService.shared.fetchAllProductsForCurrentBrand()
            for p in products { productLookup[p.id] = p }
        } catch {
            if let products = try? await DataService.shared.fetchProducts() {
                for p in products { productLookup[p.id] = p }
            }
        }

        // Top products from order_items
        let orderIds = allSales.map { $0.id }
        if !orderIds.isEmpty {
            do {
                let items = try await DataService.shared.fetchOrderItems(orderIds: orderIds)
                topProducts = computeTopProducts(from: items, productLookup: productLookup)
            } catch { print("Dashboard/OrderItems: \(error)") }
        }

        // MARK: Staff Performance
        do {
            let staff = try await DataService.shared.fetchStaff()
            let staffLookup = Dictionary(uniqueKeysWithValues: staff.map { ($0.id, $0) })
            staffPerformance = computeStaffPerformance(from: allSales, staffLookup: staffLookup)
        } catch { print("Dashboard/Staff: \(error)") }

        // MARK: Low Stock
        do {
            let inventory: [StoreInventory]
            do {
                inventory = try await DataService.shared.fetchInventoryForCurrentStore()
            } catch {
                inventory = (try? await DataService.shared.fetchInventory()) ?? []
            }
            let baselines = (try? await DataService.shared.fetchInventoryBaselineForCurrentStore()) ?? []
            let allInventory = Array(productLookup.values).map { product -> InventoryProduct in
                let baselineItem = baselines.first { $0.productId == product.id }
                let currentQty = baselineItem?.currentQuantity ?? 0
                return InventoryProduct(
                    id: baselineItem?.id ?? product.id,
                    productId: product.id,
                    name: product.name,
                    sku: product.sku ?? product.id.uuidString.prefix(8).uppercased().description,
                    category: product.category.isEmpty ? "General" : product.category,
                    price: product.price,
                    stockQuantity: currentQty,
                    baselineQuantity: baselineItem?.baselineQuantity ?? 15,
                    enabledInStore: currentQty > 0
                )
            }
            lowStockItems = allInventory.filter { $0.isLowStock }.sorted { $0.name < $1.name }
        } catch { print("Dashboard/Inventory: \(error)") }



        withAnimation(.easeInOut(duration: 0.3)) {
            self.summary = DashboardSummary(
                dailyRevenue: todayRevenue,
                targetRevenue: targetRevenue,
                activeAlertsCount: lowStockItems.count,
                todayOrderCount: orderCount,
                todayAvgOrderValue: avgOrderValue
            )
            self.activeAlerts = lowStockItems

            self.isLoading = false
        }
    }

    // MARK: - Computations

    private func computeWeekly(from sales: [SalesOrder]) -> [DailySalesData] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        var result: [DailySalesData] = []
        for daysAgo in stride(from: 6, through: 0, by: -1) {
            guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else { continue }
            let start = calendar.startOfDay(for: date)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            let amount = sales.filter { $0.createdAt >= start && $0.createdAt < end }
                              .reduce(0.0) { $0 + $1.totalAmount }
            result.append(DailySalesData(
                dayLabel: formatter.string(from: date),
                amount: amount,
                isToday: calendar.isDateInToday(date)
            ))
        }
        return result
    }

    private func computeTopProducts(from items: [DataService.OrderItemRow], productLookup: [UUID: Product]) -> [ProductSalesData] {
        var byProduct: [UUID: (units: Int, revenue: Double)] = [:]
        for item in items {
            guard let pid = item.productId else { continue }
            let qty = item.quantity ?? 0
            let rev = (item.priceAtPurchase ?? 0) * Double(qty)
            byProduct[pid, default: (0, 0)].units += qty
            byProduct[pid, default: (0, 0)].revenue += rev
        }
        return byProduct
            .compactMap { (pid, data) -> ProductSalesData? in
                let product = productLookup[pid]
                return ProductSalesData(
                    productId: pid,
                    name: product?.name ?? "Unknown Product",
                    category: product?.category ?? "General",
                    unitsSold: data.units,
                    revenue: data.revenue
                )
            }
            .sorted { $0.unitsSold > $1.unitsSold }
            .prefix(5)
            .map { $0 }
    }

    private func computeStaffPerformance(from sales: [SalesOrder], staffLookup: [UUID: User]) -> [StaffPerformanceData] {
        let filtered = sales.filter { $0.salesAssociateId != nil }
        let grouped = Dictionary(grouping: filtered) { $0.salesAssociateId! }
        
        return staffLookup.values.map { staff in
            let orders = grouped[staff.id] ?? []
            let totalSales = orders.reduce(0.0) { $0 + $1.totalAmount }
            let ratings = orders.compactMap { $0.ratingValue }.map { Double($0) }
            let avgRating = ratings.isEmpty ? 0 : ratings.reduce(0, +) / Double(ratings.count)
            
            return StaffPerformanceData(
                id: staff.id,
                name: staff.displayName ?? "Associate",
                totalSales: totalSales,
                avgRating: avgRating,
                ratingCount: ratings.count,
                orderCount: orders.count
            )
        }
        .sorted { $0.totalSales > $1.totalSales }
    }
}
