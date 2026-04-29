import Foundation

public struct DiscountCoupon: Identifiable, Codable, Sendable {
    public let id: UUID
    public let brandId: UUID
    public let createdBy: UUID
    public var code: String
    public var description: String?
    public var discountType: DiscountType
    public var discountValue: Double
    public var minOrderAmount: Double
    public var maxDiscountCap: Double?
    public var validFrom: Date
    public var validUntil: Date?
    public var usageLimit: Int?
    public var usageCount: Int
    public var isActive: Bool
    public let createdAt: Date

    public enum DiscountType: String, Codable, Sendable {
        case percentage
        case flat
        
        public var label: String {
            switch self {
            case .percentage: return "Percentage"
            case .flat: return "Flat Amount"
            }
        }
    }

    public init(
        id: UUID = UUID(),
        brandId: UUID,
        createdBy: UUID,
        code: String,
        description: String? = nil,
        discountType: DiscountType,
        discountValue: Double,
        minOrderAmount: Double = 0,
        maxDiscountCap: Double? = nil,
        validFrom: Date = Date(),
        validUntil: Date? = nil,
        usageLimit: Int? = nil,
        usageCount: Int = 0,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.brandId = brandId
        self.createdBy = createdBy
        self.code = code
        self.description = description
        self.discountType = discountType
        self.discountValue = discountValue
        self.minOrderAmount = minOrderAmount
        self.maxDiscountCap = maxDiscountCap
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.usageLimit = usageLimit
        self.usageCount = usageCount
        self.isActive = isActive
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, code, description, isActive = "is_active", createdAt = "created_at"
        case brandId = "brand_id", createdBy = "created_by"
        case discountType = "discount_type", discountValue = "discount_value"
        case minOrderAmount = "min_order_amount", maxDiscountCap = "max_discount_cap"
        case validFrom = "valid_from", validUntil = "valid_until"
        case usageLimit = "usage_limit", usageCount = "usage_count"
    }
}

public struct DiscountUsage: Identifiable, Codable, Sendable {
    public let id: UUID
    public let couponId: UUID
    public let orderId: UUID
    public let appliedBy: UUID
    public let storeId: UUID
    public let discountAmount: Double
    public let appliedAt: Date
    
    // Joined data for display
    public var storeName: String?
    public var associateName: String?

    enum CodingKeys: String, CodingKey {
        case id
        case couponId = "coupon_id"
        case orderId = "order_id"
        case appliedBy = "applied_by"
        case storeId = "store_id"
        case discountAmount = "discount_amount"
        case appliedAt = "applied_at"
        case storeName, associateName
    }
}

public struct DiscountStoreVisibility: Codable, Sendable {
    public let id: UUID
    public let couponId: UUID
    public let storeId: UUID

    enum CodingKeys: String, CodingKey {
        case id, couponId = "coupon_id", storeId = "store_id"
    }
}
