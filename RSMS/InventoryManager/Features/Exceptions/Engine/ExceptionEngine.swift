import Foundation
import Combine

@MainActor
public class ExceptionEngine: ObservableObject {
    public static let shared = ExceptionEngine()

    @Published public var exceptions: [ExceptionRecord] = []

    private init() {}

    // MARK: - Audit-session bulk processing

    public func processScanSession(
        scannedRFIDs: [String],
        targetLocation: String,
        expectedItems: [InventoryItem]
    ) {
        var newExceptions: [ExceptionRecord] = []
        let scannedSet = Set(scannedRFIDs)

        // 1. Duplicates
        var freq: [String: Int] = [:]
        scannedRFIDs.forEach { freq[$0, default: 0] += 1 }
        for (rfid, count) in freq where count > 1 {
            guard !hasPendingException(rfid: rfid, type: .duplicate) else { continue }
            let item = expectedItems.first { $0.id == rfid }
            newExceptions.append(ExceptionRecord(
                rfid: rfid, type: .duplicate, severity: .low,
                expectedLocation: targetLocation, scannedLocation: targetLocation, item: item
            ))
        }

        // 2. Missing items
        for item in expectedItems where !scannedSet.contains(item.id) {
            guard !hasPendingException(rfid: item.id, type: .missing) else { continue }
            newExceptions.append(ExceptionRecord(
                rfid: item.id, type: .missing, severity: .high,
                expectedLocation: targetLocation, item: item
            ))
        }

        exceptions.append(contentsOf: newExceptions)
        sortExceptions()
    }

    // MARK: - Location mismatch

    public func reportLocationMismatch(
        rfid: String,
        expectedLocation: String,
        scannedLocation: String,
        item: InventoryItem?
    ) {
        guard !hasPendingException(rfid: rfid, type: .mismatch) else { return }
        exceptions.append(ExceptionRecord(
            rfid: rfid, type: .mismatch, severity: .medium,
            expectedLocation: expectedLocation, scannedLocation: scannedLocation, item: item
        ))
        sortExceptions()
    }

    // MARK: - Time-based missing injection (called by AuditService / ViewModel)

    public func detectOverdueItems(items: [InventoryItem]) -> [ExceptionRecord] {
        items.compactMap { item -> ExceptionRecord? in
            guard item.status != .underRepair,
                  item.status != .scrapped,
                  item.status != .sold,
                  item.scanStatus == .overdue
            else { return nil }
            return ExceptionRecord(
                rfid: item.id, type: .missing, severity: .high,
                expectedLocation: item.location, item: item
            )
        }
    }

    public func detectCertificationIssues(items: [InventoryItem]) -> [ExceptionRecord] {
        items.compactMap { item -> ExceptionRecord? in
            guard item.status != .scrapped, item.status != .sold else { return nil }
            
            if item.authenticityStatus == .pending {
                return ExceptionRecord(
                    rfid: item.id, type: .certificationMissing, severity: .medium,
                    expectedLocation: item.location, item: item
                )
            } else if item.authenticityStatus == .failed {
                return ExceptionRecord(
                    rfid: item.id, type: .certificationExpired, severity: .high,
                    expectedLocation: item.location, item: item
                )
            }
            return nil
        }
    }


    public func injectTimeBasedExceptions(_ records: [ExceptionRecord]) {
        for record in records {
            if !hasPendingException(rfid: record.rfid, type: record.type) {
                exceptions.append(record)
            }
        }
        sortExceptions()
    }


    // MARK: - Clear on successful scan

    public func clearMissingException(for rfid: String) {
        exceptions.removeAll { $0.rfid == rfid && $0.type == .missing }
    }

    // MARK: - Resolve exception

    public func resolveException(exceptionId: UUID, action: ExceptionResolutionAction) async throws {
        guard let index = exceptions.firstIndex(where: { $0.id == exceptionId }) else { return }
        var exception = exceptions[index]

        switch action {
        case .markFound:
            if var item = exception.item {
                let now = Date()
                item.lastScannedAt = now
                item.scanCount += 1
                item.isFlaggedMissing = false
                item.status = .available
                item.refreshScanDue()
                
                try await DataService.shared.updateInventoryItem(item: item)
                try await DataService.shared.updateInventoryItemScanStatus(
                    id: item.id,
                    scanCount: item.scanCount,
                    lastAuditSessionId: item.lastAuditSessionId
                )
                
                AuditService.shared.log(itemId: item.id, action: .scanned, metadata: "Exception Resolved: Found")
            }
        case .confirmMissing:
            if var item = exception.item {
                item.status = .scrapped
                try await DataService.shared.updateInventoryItem(item: item)
                AuditService.shared.log(itemId: item.id, action: .statusChanged, metadata: "Exception Resolved: Confirmed Missing -> Scrapped")
            }
        case .updateLocation:
            if let newLocation = exception.scannedLocation {
                try await DataService.shared.updateInventoryItemLocation(
                    id: exception.rfid, newLocation: newLocation
                )
                AuditService.shared.log(itemId: exception.rfid, action: .moved, metadata: "Exception Resolved: Location Updated to \(newLocation)")
            }
        case .ignoreDuplicate:
            AuditService.shared.log(itemId: exception.rfid, action: .scanned, metadata: "Exception Resolved: Ignored Duplicate")
            
        case .fileInsuranceClaim:
            // Future: Integration with carrier APIs or insurance provider
            AuditService.shared.log(itemId: exception.rfid, action: .statusChanged, metadata: "Exception Resolved: Insurance Claim Filed")
            
        case .markAsScrapped:
            if var item = exception.item {
                item.status = .scrapped
                try await DataService.shared.updateInventoryItem(item: item)
                AuditService.shared.log(itemId: item.id, action: .statusChanged, metadata: "Exception Resolved: Marked as Scrapped")
            }
            
        case .approveShortage:
            // Reconcile the original order/shipment record
            AuditService.shared.log(itemId: exception.rfid, action: .statusChanged, metadata: "Exception Resolved: Shortage Approved")

        case .uploadCertificate, .renewCertificate:
            // Handled via the UI (uploading a document updates the status)
            // Once updated, the app refreshes and the exception should be cleared if the item is re-scanned or manual refreshed
            AuditService.shared.log(itemId: exception.rfid, action: .statusChanged, metadata: "Exception Resolved: Certification Updated")
        }


        exception.isResolved = true
        exceptions[index] = exception
        exceptions.removeAll { $0.isResolved }
        
        // Notify observers to trigger refresh (e.g., dashboard)
        NotificationCenter.default.post(name: NSNotification.Name("ExceptionResolved"), object: nil)
    }


    // MARK: - Computed counts

    public var missingCount: Int   { exceptions.filter { $0.type == .missing   }.count }
    public var mismatchCount: Int  { exceptions.filter { $0.type == .mismatch  }.count }
    public var duplicateCount: Int { exceptions.filter { $0.type == .duplicate }.count }
    public var totalCount: Int     { exceptions.count }

    // MARK: - Helpers

    private func hasPendingException(rfid: String, type: ExceptionType) -> Bool {
        exceptions.contains { $0.rfid == rfid && $0.type == type }
    }

    private func sortExceptions() {
        exceptions.sort { $0.severity.sortWeight > $1.severity.sortWeight }
    }
    
    public var damagedCount: Int {
        exceptions.filter { $0.type == .damaged }.count
    }
    
    public var shortageCount: Int {
        exceptions.filter { $0.type == .shortage }.count
    }
}
