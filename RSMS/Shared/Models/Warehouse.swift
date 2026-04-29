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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? ""
        location = (try? container.decodeIfPresent(String.self, forKey: .location)) ?? ""
        address = try? container.decodeIfPresent(String.self, forKey: .address)
        brandId = try? container.decodeIfPresent(UUID.self, forKey: .brandId)
        status = try? container.decodeIfPresent(String.self, forKey: .status)
        createdAt = try? container.decodeIfPresent(String.self, forKey: .createdAt)
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
