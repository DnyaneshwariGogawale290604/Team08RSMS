import Foundation

struct SAOrder: Identifiable, Decodable, Sendable {
    let id: UUID
    let totalAmount: Double
    let amountPaid: Double       // amount already collected
    let paymentStatus: String?   // "paid", "partially_paid", "unpaid"
    var status: String?
    var shippingStatus: String?  // from shipping_status column
    let createdAt: String?
    let customerName: String?    // joined from customers table

    /// Amount still outstanding
    var dueAmount: Double { max(totalAmount - amountPaid, 0) }

    enum CodingKeys: String, CodingKey {
        case id = "order_id"
        case totalAmount    = "total_amount"
        case amountPaid     = "amount_paid"
        case paymentStatus  = "payment_status"
        case status
        case shippingStatus = "shipping_status"
        case createdAt      = "created_at"
        case customerName   = "customers"
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

        // Handle amount_paid as Double or String (may be NULL → 0)
        if let val = try? c.decode(Double.self, forKey: .amountPaid) {
            amountPaid = val
        } else if let str = try? c.decode(String.self, forKey: .amountPaid), let val = Double(str) {
            amountPaid = val
        } else {
            amountPaid = 0
        }

        paymentStatus   = try? c.decodeIfPresent(String.self, forKey: .paymentStatus)
        status          = try c.decodeIfPresent(String.self, forKey: .status)
        shippingStatus  = try c.decodeIfPresent(String.self, forKey: .shippingStatus)
        createdAt       = try c.decodeIfPresent(String.self, forKey: .createdAt)

        // Decode nested customers object: { "name": "..." } or array [{ "name": "..." }]
        struct CustomerName: Decodable { let name: String? }
        if let nested = try? c.decodeIfPresent(CustomerName.self, forKey: .customerName) {
            customerName = nested.name
        } else if let arr = try? c.decodeIfPresent([CustomerName].self, forKey: .customerName),
                  let first = arr.first {
            customerName = first.name
        } else {
            customerName = nil
        }
    }

    /// Convenience init for constructing SAOrder directly (e.g. from local PlacedOrder)
    init(id: UUID, totalAmount: Double, amountPaid: Double = 0, paymentStatus: String? = nil,
         status: String?, shippingStatus: String? = nil, createdAt: String?, customerName: String? = nil) {
        self.id = id
        self.totalAmount = totalAmount
        self.amountPaid = amountPaid
        self.paymentStatus = paymentStatus
        self.status = status
        self.shippingStatus = shippingStatus
        self.createdAt = createdAt
        self.customerName = customerName
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
