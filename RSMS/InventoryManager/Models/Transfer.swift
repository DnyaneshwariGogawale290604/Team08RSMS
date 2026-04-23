import Foundation

public enum TransferStatus: String, Codable, CaseIterable, Sendable {
    case pending = "Pending"
    case approved = "Approved"
    case placed = "Placed"
    case dispatched = "Dispatched"
    case inTransit = "In Transit"
    case delivered = "Delivered"
    case received = "Received"
    case returned = "Returned"
    case rejected = "Rejected"
}

public enum TransferType: String, Codable, CaseIterable, Sendable {
    case vendor = "Vendor"
    case boutique = "Boutique"
}

public struct Transfer: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var type: TransferType
    public var orderId: String
    public var fromLocation: String
    public var toLocation: String
    public var status: TransferStatus
    public var batchNumber: String
    public var date: Date
    public var items: [TransferItem]
    public var isAdminApproved: Bool
    public var associatedSerials: [String]? // Mapped RFIDs (IM-15)
    public var adminActionReason: String?
    public var statusUpdatedAt: Date?
    public var vendorOrderId: String?
    public var vendorId: String?
    public var vendorContactInfo: String?
    
    public init(id: UUID = UUID(), type: TransferType, orderId: String, fromLocation: String, toLocation: String, status: TransferStatus, batchNumber: String, date: Date = Date(), items: [TransferItem], isAdminApproved: Bool = false, associatedSerials: [String]? = nil, adminActionReason: String? = nil, statusUpdatedAt: Date? = nil, vendorOrderId: String? = nil, vendorId: String? = nil, vendorContactInfo: String? = nil) {
        self.id = id
        self.type = type
        self.orderId = orderId
        self.fromLocation = fromLocation
        self.toLocation = toLocation
        self.status = status
        self.batchNumber = batchNumber
        self.date = date
        self.items = items
        self.isAdminApproved = isAdminApproved
        self.associatedSerials = associatedSerials
        self.adminActionReason = adminActionReason
        self.statusUpdatedAt = statusUpdatedAt
        self.vendorOrderId = vendorOrderId
        self.vendorId = vendorId
        self.vendorContactInfo = vendorContactInfo
    }
    
    // MARK: - Supabase Bridge
    
    public static func mapStatus(_ s: String?) -> TransferStatus {
        guard let s = s else { return .pending }
        let l = s.lowercased()
        if l.contains("transit") { return .inTransit }
        if l.contains("dispatch") { return .dispatched }
        if l.contains("deliver") { return .delivered }
        if l.contains("approve") { return .approved }
        if l.contains("reject") { return .rejected }
        if l.contains("receiv") { return .received }
        if l.contains("placed") { return .placed }
        return .pending
    }
    
    public init(fromVendorOrder vo: VendorOrder) {
        self.init(
            id: vo.id,
            type: .vendor,
            orderId: "PO-\(vo.id.uuidString.prefix(4).uppercased())",
            fromLocation: "Vendor",
            toLocation: "Warehouse",
            status: Transfer.mapStatus(vo.status),
            batchNumber: "B-\(vo.id.uuidString.prefix(4).uppercased())",
            date: vo.createdAt ?? Date(),
            items: [], // Simplified for UI display
            isAdminApproved: vo.status?.lowercased() == "approved",
            vendorOrderId: vo.id.uuidString
        )
    }
    
    public init(fromProductRequest pr: ProductRequest) {
        let pName = pr.product?.name ?? "Product"
        self.init(
            id: pr.id,
            type: .boutique,
            orderId: "REQ-\(pr.id.uuidString.prefix(4).uppercased())",
            fromLocation: "Warehouse",
            toLocation: pr.store?.name ?? "Store",
            status: Transfer.mapStatus(pr.status),
            batchNumber: "B-\(pr.id.uuidString.prefix(4).uppercased())",
            date: pr.requestDate,
            items: [TransferItem(productName: pName, quantity: pr.requestedQuantity)],
            isAdminApproved: pr.status == "approved"
        )
    }
    
    public init(fromShipment sh: Shipment) {
        let pName = sh.request?.product?.name ?? "Product"
        self.init(
            id: sh.id,
            type: .boutique,
            orderId: "SHP-\(sh.id.uuidString.prefix(4).uppercased())",
            fromLocation: "Warehouse",
            toLocation: sh.request?.store?.name ?? "Store",
            status: Transfer.mapStatus(sh.status),
            batchNumber: "B-\(sh.batchId?.uuidString.prefix(4).uppercased() ?? "1000")",
            date: sh.createdAt ?? Date(),
            items: [TransferItem(productName: pName, quantity: sh.request?.requestedQuantity ?? 1)],
            isAdminApproved: true
        )
    }
}
