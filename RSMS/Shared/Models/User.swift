import Foundation

public struct User: Identifiable, Codable, Hashable, Sendable {
    public enum Role: String, Codable, Hashable, Sendable, CaseIterable {
        case admin = "Corporate Admin"
        case manager = "Boutique Manager"
        case sales = "Sales Associate"
        case inventory = "Inventory Controller"
        case cashier = "Cashier"
    }

    public var id: UUID
    public var name: String?
    public var email: String?
    public var phone: String?
    public var brandId: UUID?
    public var createdAt: String?
    public var role: Role?
    
    // Performance Metrics
    public var averageRating: Double?
    public var ratingCount: Int?
    public var totalSales: Double?

    public init(
        id: UUID,
        name: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        brandId: UUID? = nil,
        createdAt: String? = nil,
        role: Role? = nil
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.phone = phone
        self.brandId = brandId
        self.createdAt = createdAt
        self.role = role
    }

    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case name
        case email
        case phone
        case brandId = "brand_id"
        case createdAt = "created_at"
    }

    public var displayName: String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Unnamed Employee" : trimmed
    }
}
