import Foundation

public struct Role: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String // CorporateAdmin, BoutiqueManager, InventoryManager, SalesAssociate
    public var permissions: [String: Bool]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case permissions
    }
}
