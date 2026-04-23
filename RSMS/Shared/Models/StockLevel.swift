import Foundation

public struct StockLevel: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var sku: String
    public var location: String
    public var quantity: Int
    public var lastUpdated: Date
    
    public init(id: UUID = UUID(), sku: String, location: String, quantity: Int = 0, lastUpdated: Date = Date()) {
        self.id = id
        self.sku = sku
        self.location = location
        self.quantity = quantity
        self.lastUpdated = lastUpdated
    }
}
