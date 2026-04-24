import Foundation

public struct GoodsReceivedNote: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID           // grn_id
    public var shipmentId: UUID?
    public var requestId: UUID?
    public var receivedBy: UUID?
    public var receivedAt: Date?
    public var quantityReceived: Int
    public var condition: GRNCondition
    public var notes: String?
    public var grnNumber: String?
    public var createdAt: Date?

    public enum GRNCondition: String, Codable, CaseIterable, Sendable {
        case good = "good"
        case damaged = "damaged"
        case partial = "partial"

        public var displayName: String {
            switch self {
            case .good: return "All Good"
            case .damaged: return "Damaged"
            case .partial: return "Partial Receipt"
            }
        }

        public var icon: String {
            switch self {
            case .good: return "checkmark.seal.fill"
            case .damaged: return "exclamationmark.triangle.fill"
            case .partial: return "questionmark.circle.fill"
            }
        }
    }

    enum CodingKeys: String, CodingKey {
        case id = "grn_id"
        case shipmentId = "shipment_id"
        case requestId = "request_id"
        case receivedBy = "received_by"
        case receivedAt = "received_at"
        case quantityReceived = "quantity_received"
        case condition
        case notes
        case grnNumber = "grn_number"
        case createdAt = "created_at"
    }
}
