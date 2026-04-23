import Foundation
import Combine
import Supabase
import PostgREST

@MainActor
public class InventoryEngine: ObservableObject {
    public static let shared = InventoryEngine()
    
    @Published public var inventory: [InventoryItem] = []
    @Published public var transfers: [Transfer] = []
    @Published public var demands: [Transfer] = [] // Pending requests
    @Published public var stockLevels: [StockLevel] = [] // IM-1 Aggregate map
    
    @Published public var isLoading = false
    @Published public var errorMessage: String? = nil
    
    private let client = SupabaseManager.shared.client
    
    private init() {
        // Load initial mock state in case DB fails
        self.inventory = [
            InventoryItem(id: "RFID-1001", serialId: "SN-001", productId: UUID(), batchNo: "B-21", certificateId: "CERT-A", productName: "Gold Necklace", category: "Necklace", location: "Vault A", status: .available),
            InventoryItem(id: "RFID-1002", serialId: "SN-002", productId: UUID(), batchNo: "B-21", certificateId: "CERT-B", productName: "Diamond Ring", category: "Ring", location: "New York Store", status: .reserved),
            InventoryItem(id: "RFID-1003", serialId: "SN-003", productId: UUID(), batchNo: "B-21", certificateId: "CERT-C", productName: "Gold Necklace", category: "Necklace", location: "Vault A", status: .available)
        ]
        
        self.transfers = [
            Transfer(type: .boutique, orderId: "ORD-921", fromLocation: "DC", toLocation: "Paris Boutique", status: .inTransit, batchNumber: "B-21", items: [TransferItem(productName: "Diamond Ring", quantity: 1)]),
            Transfer(type: .vendor, orderId: "PO-401", fromLocation: "Aurum Suppliers", toLocation: "Warehouse", status: .delivered, batchNumber: "B-22", items: [TransferItem(productName: "Gold Bar", quantity: 5)], isAdminApproved: true)
        ]
        
        self.demands = [
            Transfer(type: .boutique, orderId: "REQ-001", fromLocation: "DC", toLocation: "Tokyo Boutique", status: .pending, batchNumber: "REQ", items: [TransferItem(productName: "Gold Necklace", quantity: 1)])
        ]
        
        self.stockLevels = [
            StockLevel(sku: "Gold Necklace", location: "Vault A", quantity: 2),
            StockLevel(sku: "Diamond Ring", location: "New York Store", quantity: 1)
        ]
    }
    
    // MARK: - Aggregate Stock Core (IM-1)
    
    public func updateStockLevel(sku: String, location: String, quantityDelta: Int) {
        if let idx = stockLevels.firstIndex(where: { $0.sku == sku && $0.location == location }) {
            stockLevels[idx].quantity += quantityDelta
            stockLevels[idx].lastUpdated = Date()
        } else {
            let newLevel = StockLevel(sku: sku, location: location, quantity: max(0, quantityDelta)) // Prevents negative floor initially
            stockLevels.append(newLevel)
        }
    }
    
    public func getStock(sku: String, location: String) -> Int {
        return stockLevels.first(where: { $0.sku == sku && $0.location == location })?.quantity ?? 0
    }
    
    // MARK: - State Accessors
    
    public var availableCount: Int { inventory.filter { $0.status == .available }.count }
    public var reservedCount: Int { inventory.filter { $0.status == .reserved }.count }
    public var inTransitCount: Int { inventory.filter { $0.status == .inTransit }.count }
    public var soldCount: Int { inventory.filter { $0.status == .sold }.count }
    
    // MARK: - Flow 3: Dispatch & Fulfillment
    
    public func dispatch(demand: Transfer) async {
        isLoading = true
        // 1. Move demand to transfers
        if let index = demands.firstIndex(where: { $0.id == demand.id }) {
            demands.remove(at: index)
        }
        var newTransfer = demand
        newTransfer.status = .dispatched
        transfers.append(newTransfer)
        
        // 2. Change inventory states
        for demandItem in demand.items {
            let availableForProduct = inventory.filter { $0.productName == demandItem.productName && $0.status == .available }
            let toDispatch = min(availableForProduct.count, demandItem.quantity)
            
            for i in 0..<toDispatch {
                if let idx = inventory.firstIndex(where: { $0.id == availableForProduct[i].id }) {
                    inventory[idx].status = .inTransit
                    inventory[idx].location = "In Transit to \(demand.toLocation)"
                }
            }
        }
        
        // Active Supabase Map
        // try? await client.from("transfers").insert(newTransfer).execute()
        isLoading = false
    }
    
    // IM-6: Manual update of shipment status
    public func updateTransferStatus(transferId: UUID, newStatus: TransferStatus) async {
        if let index = transfers.firstIndex(where: { $0.id == transferId }) {
             transfers[index].status = newStatus
             // try? await client.from("transfers").update(["status": newStatus.rawValue]).eq("id", value: transferId).execute()
        }
    }
    
    // IM-7: Record Incoming Batch (Batch Processing)
    public func receiveBatch(transferId: UUID, serials: [String], designatedLocation: String = "Main Vault") throws {
        guard let index = transfers.firstIndex(where: { $0.id == transferId }) else { return }
        let transfer = transfers[index]
        
        let expectedQuantity = transfer.items.reduce(0) { $0 + $1.quantity }
        guard serials.count == expectedQuantity else {
            throw SerializationError.countMismatch(expected: expectedQuantity, received: serials.count)
        }
        
        let uniqueSerials = Set(serials)
        guard uniqueSerials.count == serials.count else {
            throw SerializationError.duplicateInput
        }
        
        // Prevent DB collisions
        let existingSerials = Set(inventory.map { $0.serialId })
        let intersection = uniqueSerials.intersection(existingSerials)
        guard intersection.isEmpty else {
            throw SerializationError.alreadyExists(serial: intersection.first!)
        }
        
        // Mark the transfer completely as received/delivered
        transfers[index].status = .received
        
        // IM-0: Serialization mapping locally
        var serialIndex = 0
        for transferItem in transfer.items {
            for _ in 0..<transferItem.quantity {
                guard serialIndex < serials.count else { break }
                let assignedSerial = serials[serialIndex]
                
                let newItem = InventoryItem(
                    id: "RFID-\(UUID().uuidString.prefix(8))",
                    serialId: assignedSerial,
                    productId: UUID(),
                    batchNo: transfer.batchNumber,
                    certificateId: nil,
                    productName: transferItem.productName,
                    category: "Vendor Delivery",
                    location: designatedLocation,
                    status: .available 
                )
                inventory.insert(newItem, at: 0)
                serialIndex += 1
            }
            
            // IM-1: Automatically bump aggregate stock map sequentially by quantities processed.
            updateStockLevel(sku: transferItem.productName, location: designatedLocation, quantityDelta: transferItem.quantity)
        }
    }
    
    // MARK: - Global RFID Scanning (Auditing Tracker)
    
    public func scanAndLogItem(rfid: String, newLocation: String) throws -> InventoryItem {
        guard let idx = inventory.firstIndex(where: { $0.id == rfid }) else {
            throw SerializationError.invalidRFID(rfid: rfid)
        }
        
        let oldLocation = inventory[idx].location
        let sku = inventory[idx].productName // Mapped identically as IM-1 sku backup
        
        // Physically alter localized tracking array mapping!
        inventory[idx].location = newLocation
        inventory[idx].timestamp = Date()
        
        // Dynamically Shift IM-1 Aggregate Quantities Tracking globally
        if oldLocation != newLocation {
            updateStockLevel(sku: sku, location: oldLocation, quantityDelta: -1)
            updateStockLevel(sku: sku, location: newLocation, quantityDelta: 1)
        }
        
        return inventory[idx]
    }
    
    // IM-14: Admin Approval flow
    public func sendForAdminApproval(demandId: UUID) {
        if let idx = demands.firstIndex(where: { $0.id == demandId }) {
            demands[idx].status = .pending // Mark as pending
            demands[idx].statusUpdatedAt = Date()
        }
    }
    
    // IM-3 & IM-4: Corporate Admin processes PO approval
    public func processAdminDecision(demandId: UUID, isApproved: Bool, reason: String) {
        if let idx = demands.firstIndex(where: { $0.id == demandId }) {
            demands[idx].adminActionReason = reason
            demands[idx].statusUpdatedAt = Date()
            
            if isApproved {
                demands[idx].isAdminApproved = true
                demands[idx].status = .approved
                
                // Move approved request to active transfers
                let approvedTransfer = demands[idx]
                demands.remove(at: idx)
                transfers.append(approvedTransfer)
            } else {
                demands[idx].isAdminApproved = false
                demands[idx].status = .rejected
            }
        }
    }
    
    // Convert Approved PO into actively Placed supplier order
    public func placeVendorOrder(transferId: UUID, vendorId: String, contactInfo: String) {
        if let idx = transfers.firstIndex(where: { $0.id == transferId }) {
            transfers[idx].vendorId = vendorId
            transfers[idx].vendorContactInfo = contactInfo
            transfers[idx].vendorOrderId = "VORD-\(Int.random(in: 1000...9999))"
            transfers[idx].status = .placed
            transfers[idx].statusUpdatedAt = Date()
        }
    }
    
    // IM-15: Map Outbound Serials (Scanning for Picklist)
    public func fulfillPickList(demandId: UUID, rfids: [String]) async {
        guard let index = demands.firstIndex(where: { $0.id == demandId }) else { return }
        var demand = demands[index]
        
        // Remove from demands
        demands.remove(at: index)
        
        // Move to transfers list
        demand.associatedSerials = rfids
        demand.status = .dispatched
        transfers.append(demand)
        
        // Mark actual scanned RFIDs as shipped
        for rfid in rfids {
            if let i = inventory.firstIndex(where: { $0.id == rfid }) {
                inventory[i].status = .inTransit
                inventory[i].location = "In Transit to \(demand.toLocation)"
            }
        }
    }
    
    // MARK: - Flow 2: RFID Scanning & Serialization
    
    public func assignSerialAndAdd(rfid: String, productName: String) async {
        do {
            // Attempt to pull the specific Product template from Supabase
            // Utilizing the existing products table you defined!
            let products: [Product] = try await client.from("products")
                .select()
                .eq("name", value: productName)
                .execute()
                .value
                
            if let matchedProduct = products.first {
                let newItem = InventoryItem(
                    id: rfid,
                    serialId: "SN-\(Int.random(in: 1000...9999))",
                    productId: matchedProduct.id,
                    batchNo: "B-NEW",
                    certificateId: nil,
                    productName: matchedProduct.name,
                    category: matchedProduct.category,
                    location: "Scanning Bay",
                    status: .available
                )
                inventory.insert(newItem, at: 0)
                
                // Active Supabase insertion to reflect the physical scan instantly!
                try await client.from("inventory_items").insert(newItem).execute()
            } else {
                // Fallback if product not found in Supabase
                let fallbackItem = InventoryItem(id: rfid, serialId: "SN-\(Int.random(in: 1000...9999))", productId: UUID(), batchNo: "B-NEW", certificateId: nil, productName: productName, category: "Scan", location: "Scanning Bay", status: .available)
                inventory.insert(fallbackItem, at: 0)
            }
            
        } catch {
            print("Failed to sync serialized product with Supabase: \(error.localizedDescription)")
            let fallbackItem = InventoryItem(id: rfid, serialId: "SN-\(Int.random(in: 1000...9999))", productId: UUID(), batchNo: "B-NEW", certificateId: nil, productName: productName, category: "Scan", location: "Scanning Bay", status: .available)
            inventory.insert(fallbackItem, at: 0)
        }
    }
    
    // MARK: - API Sink 
    
    public func fetchEndToEnd() async {
        isLoading = true
        do {
            // Actively tied to Supabase tables representing our state engine
            let fetchedItems: [InventoryItem] = try await client.from("inventory_items")
                .select()
                .execute()
                .value
                
            let fetchedTransfers: [Transfer] = try await client.from("transfers")
                .select()
                .execute()
                .value
                
            if !fetchedItems.isEmpty {
                self.inventory = fetchedItems
            }
            if !fetchedTransfers.isEmpty {
                self.transfers = fetchedTransfers
            }
            errorMessage = nil
            
        } catch {
            print("Supabase Warning: Could not fetch tables. Falling back to mock data. \(error.localizedDescription)")
            errorMessage = "Using Mock Data"
        }
        isLoading = false
    }
}

public enum SerializationError: LocalizedError {
    case duplicateInput
    case countMismatch(expected: Int, received: Int)
    case alreadyExists(serial: String)
    case invalidRFID(rfid: String)
    
    public var errorDescription: String? {
        switch self {
        case .duplicateInput:
            return "Duplicate serial numbers found in your input."
        case .countMismatch(let expected, let received):
            return "Quantity mismatch: Expected \(expected) serials, but received \(received)."
        case .alreadyExists(let serial):
            return "Serial ID \(serial) already exists in the system database."
        case .invalidRFID(let rfid):
            return "RFID \(rfid) matches no registered asset physically in the system network."
        }
    }
}
