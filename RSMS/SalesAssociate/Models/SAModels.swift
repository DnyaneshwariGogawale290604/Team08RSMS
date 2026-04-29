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

    // Supabase returns nested objects as { "name": "..." } or [{ "name": "..." }]
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        
        // Handle total_amount as Double or String
        if let val = try? c.decode(Double.self, forKey: .totalAmount) {
            totalAmount = val
        } else if let str = try? c.decode(String.self, forKey: .totalAmount), let val = Double(str) {
            totalAmount = val
        } else {
            totalAmount = 0
        }
        
        status      = try c.decodeIfPresent(String.self, forKey: .status)
        createdAt   = try c.decodeIfPresent(String.self, forKey: .createdAt)

        // Decode nested customers object: { "name": "Ananya Pandit" } or array [{ "name": "..." }]
        struct CustomerName: Decodable { let name: String? }
        if let nested = try? c.decodeIfPresent(CustomerName.self, forKey: .customerName) {
            customerName = nested.name
        } else if let nestedArray = try? c.decodeIfPresent([CustomerName].self, forKey: .customerName), let first = nestedArray.first {
            customerName = first.name
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
        case ratingValue = "rating"
    }
}

// MARK: - Trending Product (for dashboard section)
struct TrendingProduct: Identifiable {
    let id = UUID()
    let productId: UUID
    let name: String
    let category: String
    let price: Double
    let soldCount: Int
    let trendScore: Double

    /// Flame intensity 1–3 based on normalised trend score (0–100 scale, top product = 100)
    var flameLevel: Int {
        switch trendScore {
        case ..<40:  return 1   // low velocity
        case 40..<80: return 2  // moderate
        default:      return 3  // hot — near top seller
        }
    }
}
