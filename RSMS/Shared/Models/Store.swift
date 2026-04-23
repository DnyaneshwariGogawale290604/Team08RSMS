import Foundation

public struct Store: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var location: String
    public var brandId: UUID?
    public var salesTarget: Double?
    public var createdAt: String?
    public var openingDate: String?
    public var status: String?
    public var address: String?

    public init(
        id: UUID = UUID(),
        name: String = "",
        location: String = "",
        brandId: UUID? = nil,
        salesTarget: Double? = nil,
        createdAt: String? = nil,
        openingDate: String? = nil,
        status: String? = nil,
        address: String? = nil
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.brandId = brandId
        self.salesTarget = salesTarget
        self.createdAt = createdAt
        self.openingDate = openingDate
        self.status = status
        self.address = address
    }

    enum CodingKeys: String, CodingKey {
        case id = "store_id"
        case name
        case location
        case brandId = "brand_id"
        case salesTarget = "sales_target"
        case createdAt = "created_at"
        case openingDate = "opening_date"
        case status
        case address
    }

    public var displayName: String {
        if !name.isEmpty {
            return name
        }
        return "Unnamed Store"
    }
}
