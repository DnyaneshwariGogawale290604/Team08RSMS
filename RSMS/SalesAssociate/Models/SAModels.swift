import Foundation

struct SAOrder: Identifiable, Decodable, Sendable {
    let id: UUID
    let totalAmount: Double
    let status: String?
    let createdAt: String?
    let customerName: String?     // joined from customers table

    enum CodingKeys: String, CodingKey {
        case id = "order_id"
        case totalAmount = "total_amount"
        case status
        case createdAt = "created_at"
        case customerName = "customers"
    }

    // Supabase returns nested objects as { "name": "..." }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self, forKey: .id)
        totalAmount = try c.decode(Double.self, forKey: .totalAmount)
        status      = try c.decodeIfPresent(String.self, forKey: .status)
        createdAt   = try c.decodeIfPresent(String.self, forKey: .createdAt)

        // Decode nested customers object: { "name": "Ananya Pandit" }
        struct CustomerName: Decodable { let name: String? }
        if let nested = try? c.decodeIfPresent(CustomerName.self, forKey: .customerName) {
            customerName = nested.name
        } else {
            customerName = nil
        }
    }
    // Convenience init for constructing SAOrder directly (e.g. from local PlacedOrder)
    init(id: UUID, totalAmount: Double, status: String?, createdAt: String?, customerName: String? = nil) {
        self.id = id
        self.totalAmount = totalAmount
        self.status = status
        self.createdAt = createdAt
        self.customerName = customerName
    }
}

struct SACustomer: Identifiable, Decodable, Sendable {
    let id: UUID
    let name: String?
    let phone: String?
    let email: String?
    let customerCategory: String?

    enum CodingKeys: String, CodingKey {
        case id = "customer_id"
        case name
        case phone
        case email
        case customerCategory = "customer_category"
    }
}

struct SARating: Identifiable, Decodable, Sendable {
    let id: UUID        // maps to order_id
    let ratingValue: Int?

    enum CodingKeys: String, CodingKey {
        case id = "order_id"
        case ratingValue = "rating_value"
    }
}
