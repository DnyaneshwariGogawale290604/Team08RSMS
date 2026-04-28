import Foundation

public struct SalesOrder: Identifiable, Codable, Sendable {
    public let id: UUID
    public let customerId: UUID?
    public let salesAssociateId: UUID?
    public let storeId: UUID?
    public var totalAmount: Double
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

    public init(store: Store, totalSales: Double) {
        self.store = store
        self.totalSales = totalSales
    }
}
