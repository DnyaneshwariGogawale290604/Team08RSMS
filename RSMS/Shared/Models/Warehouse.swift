import Foundation

public struct Warehouse: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var location: String
    public var address: String?
    public var brandId: UUID?
    public var status: String?
    public var createdAt: String?

    public init(
        id: UUID = UUID(),
        name: String = "",
        location: String = "",
        address: String? = nil,
        brandId: UUID? = nil,
        status: String? = "active",
        createdAt: String? = nil
    ) {
        self.id = id
        self.name = name
        self.location = location
        self.address = address
        self.brandId = brandId
        self.status = status
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id = "warehouse_id"
        case name
        case location
        case address
        case brandId = "brand_id"
        case status
        case createdAt = "created_at"
    }

    public var isToggleActive: Bool {
        get { status == "active" }
    }

    public var displayLabel: String {
        if !name.isEmpty {
            return name
        }
        return "Unnamed Warehouse"
    }
}
