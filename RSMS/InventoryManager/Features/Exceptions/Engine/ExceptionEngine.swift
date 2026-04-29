import Foundation
import Combine

@MainActor
public class ExceptionEngine: ObservableObject {
    public static let shared = ExceptionEngine()
    
    @Published public var exceptions: [ExceptionRecord] = []
    
    private init() {}
    
    /// Process a completed scan session to detect missing, duplicate, and mismatch items.
    /// - Parameters:
    ///   - scannedRFIDs: A list of all raw RFIDs scanned in this session.
    ///   - targetLocation: The location where the scan was taking place.
    ///   - expectedItems: The list of items the database believes should be at `targetLocation`.
    public func processScanSession(scannedRFIDs: [String], targetLocation: String, expectedItems: [InventoryItem]) {
        var newExceptions: [ExceptionRecord] = []
        
        let scannedSet = Set(scannedRFIDs)
        
        // 1. Detect Duplicates
        // A simple duplicate detection: if the same RFID was scanned multiple times.
        var frequencyDict: [String: Int] = [:]
        for rfid in scannedRFIDs {
            frequencyDict[rfid, default: 0] += 1
        }
        for (rfid, count) in frequencyDict where count > 1 {
            let item = expectedItems.first(where: { $0.id == rfid })
            newExceptions.append(ExceptionRecord(
                rfid: rfid,
                type: .duplicate,
                severity: .low,
                expectedLocation: targetLocation,
                scannedLocation: targetLocation,
                item: item
            ))
        }
        
        // 2. Detect Missing Items
        // Expected items that were not found in the scanned set.
        let missingItems = expectedItems.filter { !scannedSet.contains($0.id) }
        for item in missingItems {
            newExceptions.append(ExceptionRecord(
                rfid: item.id,
                type: .missing,
                severity: .high,
                expectedLocation: targetLocation,
                item: item
            ))
        }
        
        // 3. Detect Location Mismatches
        // Items scanned that don't belong in the target location, but were found in the database.
        // To do this perfectly, we'd need all items in the database, but we only have expectedItems here.
        // Instead, the UI layer will pass in any "unexpected items" it found during the scan that don't belong here.
        
        // For now, append the new ones to the queue and sort by severity
        self.exceptions.append(contentsOf: newExceptions)
        self.exceptions.sort { $0.severity.sortWeight > $1.severity.sortWeight }
    }
    
    /// Called when an item is scanned that the database says belongs to a DIFFERENT location.
    public func reportLocationMismatch(rfid: String, expectedLocation: String, scannedLocation: String, item: InventoryItem?) {
        let exception = ExceptionRecord(
            rfid: rfid,
            type: .mismatch,
            severity: .medium,
            expectedLocation: expectedLocation,
            scannedLocation: scannedLocation,
            item: item
        )
        self.exceptions.append(exception)
        self.exceptions.sort { $0.severity.sortWeight > $1.severity.sortWeight }
    }
    
    /// Resolve an exception from the queue
    public func resolveException(exceptionId: UUID, action: ExceptionResolutionAction) async throws {
        guard let index = exceptions.firstIndex(where: { $0.id == exceptionId }) else { return }
        var exception = exceptions[index]
        
        switch action {
        case .markFound:
            // Item was found physically but wasn't scanned initially. Nothing changes in DB, just resolve.
            break
            
        case .confirmMissing:
            // Update inventory status to scrapped/missing. Shrink analytics will read scrapped items.
            if var item = exception.item {
                item.status = .scrapped // Mark as lost/shrinkage
                try await DataService.shared.updateInventoryItem(item: item)
                
                // Analytics Hook: If we had a ShrinkService, we'd log it here.
                // ShrinkAnalyticsEngine.logShrinkEvent(item)
            }
            
        case .updateLocation:
            // Item found in wrong location, accept the new location
            if let newLocation = exception.scannedLocation {
                try await DataService.shared.updateInventoryItemLocation(id: exception.rfid, newLocation: newLocation)
            }
            
        case .ignoreDuplicate:
            // Just clear the exception
            break
            
        case .fileInsuranceClaim:
            // Future: Integration with carrier APIs or insurance provider
            break
            
        case .markAsScrapped:
            if var item = exception.item {
                item.status = .scrapped
                try await DataService.shared.updateInventoryItem(item: item)
            }
            
        case .approveShortage:
            // Reconcile the original order/shipment record
            break
        }
        
        exception.isResolved = true
        exceptions[index] = exception
        
        // Remove resolved exceptions from active queue
        exceptions.removeAll(where: { $0.isResolved })
    }
    
    public var missingCount: Int {
        exceptions.filter { $0.type == .missing }.count
    }
    
    public var mismatchCount: Int {
        exceptions.filter { $0.type == .mismatch }.count
    }
    
    public var duplicateCount: Int {
        exceptions.filter { $0.type == .duplicate }.count
    }
    
    public var damagedCount: Int {
        exceptions.filter { $0.type == .damaged }.count
    }
    
    public var shortageCount: Int {
        exceptions.filter { $0.type == .shortage }.count
    }
}
