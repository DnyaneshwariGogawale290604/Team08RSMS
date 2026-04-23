import Foundation

public struct Vendor: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var contactInfo: String?
    public var brandId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case id = "vendor_id"
        case name
        case contactInfo = "contact_info"
        case brandId = "brand_id"
    }
}
