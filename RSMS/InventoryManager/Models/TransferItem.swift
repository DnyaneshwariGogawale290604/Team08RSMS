import Foundation

public struct TransferItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var productName: String
    public var quantity: Int
    
    public init(id: UUID = UUID(), productName: String, quantity: Int) {
        self.id = id
        self.productName = productName
        self.quantity = quantity
    }
}
