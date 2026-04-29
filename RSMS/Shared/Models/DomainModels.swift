import Foundation

public struct SalesOrder: Identifiable, Codable, Sendable {
    public let id: UUID
    public let customerId: UUID?
    public let salesAssociateId: UUID?
    public let storeId: UUID?
    public let totalAmount: Double
    public let status: String?
    public let createdAt: Date
    public let ratingValue: Int?
    public let ratingFeedback: String?

    enum CodingKeys: String, CodingKey {
        case id = "order_id"
        case customerId = "customer_id"
        case salesAssociateId = "sales_associate_id"
        case storeId = "store_id"
        case totalAmount = "total_amount"
        case status
        case createdAt = "created_at"
        case ratingValue = "rating_value"
        case ratingFeedback = "rating_feedback"
    }
}

public struct InventoryProduct: Identifiable, Codable, Sendable {
    public let id: UUID
    public var productId: UUID
    public var name: String
    public var sku: String
    public var category: String
    public var price: Double
    public var stockQuantity: Int
    public var baselineQuantity: Int
    public var enabledInStore: Bool

    public var isLowStock: Bool { stockQuantity <= baselineQuantity }
}

public struct StockAlert: Identifiable, Codable, Sendable {
    public let id: UUID
    public var productId: UUID
    public var message: String
    public var isResolved: Bool
    public var priority: AlertPriority
    public var requestStatus: String?
    public var rejectionReason: String?

    public enum AlertPriority: String, Codable, Sendable {
        case critical = "Critical"
        case medium = "Medium"
        case low = "Low"
    }
}

public struct DashboardSummary: Sendable {
    public var dailyRevenue: Double
    public var targetRevenue: Double
    public var activeAlertsCount: Int
    public var todayOrderCount: Int
    public var todayAvgOrderValue: Double
    
    public init(dailyRevenue: Double, targetRevenue: Double, activeAlertsCount: Int, todayOrderCount: Int = 0, todayAvgOrderValue: Double = 0) {
        self.dailyRevenue = dailyRevenue
        self.targetRevenue = targetRevenue
        self.activeAlertsCount = activeAlertsCount
        self.todayOrderCount = todayOrderCount
        self.todayAvgOrderValue = todayAvgOrderValue
    }
}

public struct StaffPerformanceData: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let totalSales: Double
    public let avgRating: Double
    public let ratingCount: Int
    public let orderCount: Int
}

public struct ProductSalesData: Identifiable, Sendable {
    public let id: UUID
    public let productId: UUID
    public let name: String
    public let category: String
    public let unitsSold: Int
    public let revenue: Double
    
    public init(productId: UUID, name: String, category: String, unitsSold: Int, revenue: Double) {
        self.id = UUID()
        self.productId = productId
        self.name = name
        self.category = category
        self.unitsSold = unitsSold
        self.revenue = revenue
    }
}

public struct DailySalesData: Identifiable, Sendable {
    public let id: UUID
    public let dayLabel: String
    public let amount: Double
    public let isToday: Bool
    
    public init(dayLabel: String, amount: Double, isToday: Bool) {
        self.id = UUID()
        self.dayLabel = dayLabel
        self.amount = amount
        self.isToday = isToday
    }
}

public struct AssociateRating: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let salesAssociateId: UUID
    public let ratingValue: Double
    public let feedbackText: String?
    public let createdAt: String?
}

public struct CategorySales: Identifiable, Sendable {
    public let id = UUID()
    public let category: String
    public let totalSales: Double
    
    public init(category: String, totalSales: Double) {
        self.category = category
        self.totalSales = totalSales
    }
}

public struct StorePerformance: Identifiable, Sendable {
    public var id: UUID { store.id }
    public let store: Store
    public let totalSales: Double
    public let target: Double
    public let categorySales: [CategorySales]

    public var achievementPercentage: Double {
        guard target > 0 else { return 0 }
        return totalSales / target
    }

    public init(store: Store, totalSales: Double, target: Double, categorySales: [CategorySales] = []) {
        self.store = store
        self.totalSales = totalSales
        self.target = target
        self.categorySales = categorySales
    }
}
