import Foundation
import Combine

// MARK: - Customer
public struct Customer: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let phone: String?
    public let email: String?
    public let gender: String?
    public let dateOfBirth: String?   // stored as ISO date string "YYYY-MM-DD"
    public let address: String?
    public let nationality: String?
    public let notes: String?
    public let customerCategory: String?  // "VIP" | "Regular"
    public let brandId: UUID?
    public let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id = "customer_id"; case name; case phone; case email
        case gender; case dateOfBirth = "date_of_birth"
        case address; case nationality; case notes
        case customerCategory = "customer_category"
        case brandId = "brand_id"; case createdAt = "created_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "Unnamed Client"
        phone = try? c.decodeIfPresent(String.self, forKey: .phone)
        email = try? c.decodeIfPresent(String.self, forKey: .email)
        gender = try? c.decodeIfPresent(String.self, forKey: .gender)
        dateOfBirth = try? c.decodeIfPresent(String.self, forKey: .dateOfBirth)
        address = try? c.decodeIfPresent(String.self, forKey: .address)
        nationality = try? c.decodeIfPresent(String.self, forKey: .nationality)
        notes = try? c.decodeIfPresent(String.self, forKey: .notes)
        customerCategory = try? c.decodeIfPresent(String.self, forKey: .customerCategory)
        brandId = try? c.decodeIfPresent(UUID.self, forKey: .brandId)

        if let date = try? c.decodeIfPresent(Date.self, forKey: .createdAt) {
            createdAt = date
        } else if let raw = try? c.decodeIfPresent(String.self, forKey: .createdAt) {
            createdAt = Self.parseDate(raw)
        } else {
            createdAt = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(phone, forKey: .phone)
        try c.encodeIfPresent(email, forKey: .email)
        try c.encodeIfPresent(gender, forKey: .gender)
        try c.encodeIfPresent(dateOfBirth, forKey: .dateOfBirth)
        try c.encodeIfPresent(address, forKey: .address)
        try c.encodeIfPresent(nationality, forKey: .nationality)
        try c.encodeIfPresent(notes, forKey: .notes)
        try c.encodeIfPresent(customerCategory, forKey: .customerCategory)
        try c.encodeIfPresent(brandId, forKey: .brandId)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
    }

    private static func parseDate(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: raw) { return date }

        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: raw) { return date }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = formatter.date(from: raw) { return date }

        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: raw)
    }
}

// MARK: - CustomerPreference
public struct CustomerPreference: Codable, Identifiable {
    public let id: UUID
    public let customerId: UUID
    public let preferredBrands: [String]?
    public let preferredCategories: [String]?
    public let sizeDetails: [String: String]?
    public let budgetMin: Double?
    public let budgetMax: Double?
    public let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id; case customerId = "customer_id"
        case preferredBrands = "preferred_brands"
        case preferredCategories = "preferred_categories"
        case sizeDetails = "size_details"
        case budgetMin = "budget_min"; case budgetMax = "budget_max"; case notes
    }
}

// MARK: - CustomerTag
public struct CustomerTag: Codable, Identifiable {
    public let id: UUID
    public let customerId: UUID
    public let tag: String
    
    enum CodingKeys: String, CodingKey {
        case id; case customerId = "customer_id"; case tag
    }
}

// MARK: - WishlistItem
public struct WishlistItem: Codable, Identifiable {
    public let id: UUID
    public let customerId: UUID
    public let productId: UUID
    public let addedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id; case customerId = "customer_id"; case productId = "product_id"; case addedAt = "added_at"
    }
}

// MARK: - OrderItem
public struct OrderItem: Codable, Identifiable {
    public let id: UUID
    public let orderId: UUID
    public let productId: UUID
    public let quantity: Int
    public let priceAtPurchase: Double
    
    enum CodingKeys: String, CodingKey {
        case id = "order_item_id"; case orderId = "order_id"; case productId = "product_id"
        case quantity; case priceAtPurchase = "price_at_purchase"
    }
}

// MARK: - CartItem (local)
public struct CartItem: Identifiable {
    public let id = UUID()
    public let product: Product
    public var quantity: Int
    public var selectedSize: String?
    public var lineTotal: Double { product.price * Double(quantity) }
    
    public init(product: Product, quantity: Int, selectedSize: String? = nil) {
        self.product = product
        self.quantity = quantity
        self.selectedSize = selectedSize
    }
}

// MARK: - SalesMetric
public struct SalesMetric: Codable, Identifiable {
    public let id: UUID
    public let salesAssociateId: UUID
    public let date: Date
    public let totalSalesAmount: Double
    public let targetAmount: Double
    public let achievementPercentage: Double?
    public let numberOfOrders: Int
    
    enum CodingKeys: String, CodingKey {
        case id; case salesAssociateId = "sales_associate_id"; case date
        case totalSalesAmount = "total_sales_amount"; case targetAmount = "target_amount"
        case achievementPercentage = "achievement_percentage"; case numberOfOrders = "number_of_orders"
    }
}

// MARK: - ProductTrend
public struct ProductTrend: Codable, Identifiable {
    public let id: UUID
    public let productId: UUID
    public let totalSoldCount: Int
    public let avgTimeToSell: Double?
    public let trendScore: Double?
    public let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id; case productId = "product_id"; case totalSoldCount = "total_sold_count"
        case avgTimeToSell = "avg_time_to_sell"; case trendScore = "trend_score"; case updatedAt = "updated_at"
    }
}

// MARK: - CustomerPurchaseHistory
public struct CustomerPurchaseHistory: Codable, Identifiable {
    public let id: UUID
    public let customerId: UUID
    public let orderId: UUID
    public let totalSpent: Double
    public let lastPurchaseDate: Date?
    
    enum CodingKeys: String, CodingKey {
        case id; case customerId = "customer_id"; case orderId = "order_id"
        case totalSpent = "total_spent"; case lastPurchaseDate = "last_purchase_date"
    }
}

public struct PlacedOrder: Identifiable {
    public let id: UUID
    public let orderNumber: String
    public let customer: Customer
    public let items: [CartItem]
    public let totalAmount: Double
    public let status: String
    public let createdAt: Date
    public let associateName: String
}

import SwiftUI


public class SharedOrderStore: ObservableObject {
    @Published public var orders: [PlacedOrder] = []
    
    public init() {}
    
    public func addOrder(_ order: PlacedOrder) {
        orders.append(order)
    }
}

// MARK: - Billing and Payment Models

// Payment leg item for billing
public struct BillingLegItem: Identifiable {
    public let id = UUID()
    public var itemNumber: Int
    public var amount: Double
    public var method: String // "upi", "cash", "netbanking"
    public var tendered: Double? // only for cash
    public var note: String?

    // State awareness
    public var existingStatus: String? = nil // "paid", "pending", "failed", "cancelled"
    public var existingItemId: String? = nil // DB UUID of this item

    // Computed helpers
    public var isPaid: Bool { existingStatus == "paid" }
    public var isPending: Bool {
        existingStatus == nil || existingStatus == "pending"
    }
    public var isNew: Bool { existingItemId == nil }

    public init(
        itemNumber: Int,
        amount: Double,
        method: String,
        tendered: Double? = nil,
        note: String? = nil,
        existingStatus: String? = nil,
        existingItemId: String? = nil
    ) {
        self.itemNumber = itemNumber
        self.amount = amount
        self.method = method
        self.tendered = tendered
        self.note = note
        self.existingStatus = existingStatus
        self.existingItemId = existingItemId
    }
}

// Payment leg for billing
public struct BillingLeg: Identifiable {
    public let id = UUID()
    public var legNumber: Int
    public var dueType: String // "immediate", "on_delivery"
    public var totalAmount: Double
    public var items: [BillingLegItem]

    // State awareness
    public var existingStatus: String? = nil // "paid", "partially_paid", "pending", "cancelled"
    public var existingLegId: String? = nil // DB UUID of this leg

    // Computed helpers
    public var isPaid: Bool { existingStatus == "paid" }
    public var isPartiallyPaid: Bool { existingStatus == "partially_paid" }
    public var isNew: Bool { existingLegId == nil }
    public var isFullyLocked: Bool { existingStatus == "paid" }
    public var hasAnyPaidItem: Bool { items.contains { $0.isPaid } }

    public var itemsTotal: Double {
        items.reduce(0) { $0 + $1.amount }
    }
    public var isBalanced: Bool {
        abs(itemsTotal - totalAmount) < 0.01
    }

    // Amount that is locked (already paid)
    public var lockedAmount: Double {
        items.filter { $0.isPaid }.reduce(0) { $0 + $1.amount }
    }

    // Amount still pending
    public var pendingAmount: Double {
        items.filter { $0.isPending }.reduce(0) { $0 + $1.amount }
    }

    public init(
        legNumber: Int,
        dueType: String,
        totalAmount: Double,
        items: [BillingLegItem],
        existingStatus: String? = nil,
        existingLegId: String? = nil
    ) {
        self.legNumber = legNumber
        self.dueType = dueType
        self.totalAmount = totalAmount
        self.items = items
        self.existingStatus = existingStatus
        self.existingLegId = existingLegId
    }
}

// Payment leg item from DB (for BillAndPaymentsView)
public struct PaymentLegItemRecord: Identifiable, Decodable {
    public let id: UUID
    public let itemNumber: Int
    public let amount: Double
    public let method: String
    public let status: String
    public let collectedAt: String?
    public let note: String?
    public let receiptUrl: String?

    public enum CodingKeys: String, CodingKey {
        case id
        case itemNumber = "item_number"
        case amount
        case method
        case status
        case collectedAt = "collected_at"
        case note
        case receiptUrl = "receipt_url"
    }
}

// Payment leg from DB (for BillAndPaymentsView)
public struct PaymentLegRecord: Identifiable, Decodable {
    public let id: UUID
    public let legNumber: Int
    public let dueType: String
    public let totalAmount: Double
    public let amountPaid: Double
    public let status: String
    public let collectedAt: String?
    public var items: [PaymentLegItemRecord]

    public enum CodingKeys: String, CodingKey {
        case id
        case legNumber = "leg_number"
        case dueType = "due_type"
        case totalAmount = "total_amount"
        case amountPaid = "amount_paid"
        case status
        case collectedAt = "collected_at"
        case items
    }
}

// Full order payment summary from get-order-payment-summary
public struct OrderPaymentSummary {
    public let orderId: String
    public let totalAmount: Double
    public let amountPaid: Double
    public let remaining: Double
    public let paymentStatus: String
    public let isFullyPaid: Bool
    public let legs: [PaymentLegRecord]
    public let maxPaymentLegs: Int
    public let maxLegSplits: Int
    public let enabledMethods: [String]

    public init(orderId: String, totalAmount: Double, amountPaid: Double, remaining: Double, paymentStatus: String, isFullyPaid: Bool, legs: [PaymentLegRecord], maxPaymentLegs: Int, maxLegSplits: Int, enabledMethods: [String]) {
        self.orderId = orderId
        self.totalAmount = totalAmount
        self.amountPaid = amountPaid
        self.remaining = remaining
        self.paymentStatus = paymentStatus
        self.isFullyPaid = isFullyPaid
        self.legs = legs
        self.maxPaymentLegs = maxPaymentLegs
        self.maxLegSplits = maxLegSplits
        self.enabledMethods = enabledMethods
    }
}
