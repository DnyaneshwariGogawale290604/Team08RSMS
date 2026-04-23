import Foundation

// MARK: - Transaction
public struct Transaction: Codable, Identifiable {
    public let id: UUID
    public let orderId: UUID
    public let paymentMethod: String
    public let paymentStatus: String
    public let amountPaid: Double
    public let transactionTime: Date?
    
    enum CodingKeys: String, CodingKey {
        case id; case orderId = "order_id"; case paymentMethod = "payment_method"
        case paymentStatus = "payment_status"; case amountPaid = "amount_paid"
        case transactionTime = "transaction_time"
    }
}

// MARK: - Receipt
public struct Receipt: Codable, Identifiable {
    public let id: UUID
    public let orderId: UUID
    public let receiptUrl: String?
    public let generatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id; case orderId = "order_id"; case receiptUrl = "receipt_url"; case generatedAt = "generated_at"
    }
}

// MARK: - OrderTracking
public struct OrderTracking: Codable, Identifiable {
    public let id: UUID
    public let orderId: UUID
    public let status: String
    public let priorityLevel: String
    public let estimatedDelivery: Date?
    public let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id; case orderId = "order_id"; case status
        case priorityLevel = "priority_level"; case estimatedDelivery = "estimated_delivery"; case updatedAt = "updated_at"
    }
}
