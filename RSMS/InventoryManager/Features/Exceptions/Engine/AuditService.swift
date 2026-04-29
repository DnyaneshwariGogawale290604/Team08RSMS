import Foundation
import Combine

// MARK: - AuditService
// Responsible for: AuditLog CRUD, item scan lifecycle, cycle-count computation.
// Kept separate from ExceptionEngine — this service only manages state; the engine renders exceptions.

@MainActor
public final class AuditService: ObservableObject {
    public static let shared = AuditService()

    // In-memory audit trail (keyed by itemId for fast lookup)
    @Published public var auditLogs: [AuditLog] = []

    private init() {}

    // MARK: - Record an action

    public func log(
        itemId: String,
        action: AuditLogAction,
        userId: String? = nil,
        metadata: String? = nil
    ) {
        let entry = AuditLog(itemId: itemId, action: action, userId: userId, metadata: metadata)
        auditLogs.insert(entry, at: 0)  // newest first

        // Persist to Supabase in background (best-effort)
        Task {
            try? await DataService.shared.insertAuditLog(entry)
        }
    }

    // MARK: - Load logs for a specific item
    public func loadLogs(for itemId: String) async {
        if let fetched = try? await DataService.shared.fetchAuditLogs(for: itemId) {
            let existing = Set(auditLogs.map(\.id))
            let newLogs = fetched.filter { !existing.contains($0.id) }
            auditLogs.insert(contentsOf: newLogs, at: auditLogs.endIndex)
        }
    }

    // Filtered view for a given item
    public func logs(for itemId: String) -> [AuditLog] {
        auditLogs
            .filter { $0.itemId == itemId }
            .sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - On-Item Scan

    /// Call this when a user explicitly scans a single item.
    /// Returns the updated item.
    public func recordScan(
        item: InventoryItem,
        auditSessionId: UUID? = nil
    ) async throws -> InventoryItem {
        var updated = item
        updated.lastScannedAt = Date()
        updated.scanCount = item.scanCount + 1
        updated.lastAuditSessionId = auditSessionId
        updated.isFlaggedMissing = false
        updated.refreshScanDue()

        // Persist
        try await DataService.shared.updateInventoryItemScanStatus(
            id: updated.id,
            scanCount: updated.scanCount,
            lastAuditSessionId: updated.lastAuditSessionId
        )

        // Remove any existing missing exception for this item
        ExceptionEngine.shared.clearMissingException(for: updated.id)

        // Audit log
        log(itemId: updated.id, action: .scanned,
            metadata: "Session: \(auditSessionId?.uuidString ?? "manual")")
            
        // Certification Check
        if updated.authenticityStatus != .verified {
            let certException = ExceptionRecord(
                rfid: updated.id,
                type: updated.authenticityStatus == .pending ? .certificationMissing : .certificationExpired,
                severity: updated.authenticityStatus == .pending ? .medium : .high,
                expectedLocation: updated.location,
                item: updated
            )
            ExceptionEngine.shared.injectTimeBasedExceptions([certException])
        }


        // Notify observers to trigger refresh (e.g., dashboard)
        NotificationCenter.default.post(name: NSNotification.Name("ExceptionResolved"), object: nil)
        
        return updated
    }

    // MARK: - Cycle Count: detect overdue items

    public func detectOverdueItems(from items: [InventoryItem]) -> [InventoryItem] {
        items.filter { item in
            guard item.status != .underRepair,
                  item.status != .scrapped,
                  item.status != .sold
            else { return false }
            return item.scanStatus == .overdue
        }
    }

    // MARK: - Bulk Scan Processing

    public func recordBulkScan(
        rfids: [String],
        auditSessionId: UUID
    ) async {
        // Fetch items matching these RFIDs
        guard let items = try? await DataService.shared.fetchInventoryItems() else { return }
        
        for rfid in rfids {
            if let item = items.first(where: { $0.id == rfid }) {
                _ = try? await recordScan(item: item, auditSessionId: auditSessionId)
            }
        }
    }

    // MARK: - Certification Logic

    public func refreshItemAuthenticity(item: InventoryItem) async throws -> InventoryItem {
        let certifications = try await DataService.shared.fetchCertifications(for: item.id)
        var updated = item
        
        if certifications.isEmpty {
            updated.authenticityStatus = .pending
        } else {
            let now = Date()
            let hasValid = certifications.contains { cert in
                cert.status == .valid && (cert.expiryDate == nil || cert.expiryDate! > now)
            }
            let hasExpired = certifications.contains { cert in
                cert.status == .expired || (cert.expiryDate != nil && cert.expiryDate! <= now)
            }
            
            if hasValid {
                updated.authenticityStatus = .verified
            } else if hasExpired {
                updated.authenticityStatus = .failed
            } else {
                updated.authenticityStatus = .pending
            }
        }
        
        try await DataService.shared.updateInventoryItemAuthenticity(
            id: updated.id,
            status: updated.authenticityStatus,
            certificationIds: certifications.map { $0.id }
        )
        
        return updated
    }
}

