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
