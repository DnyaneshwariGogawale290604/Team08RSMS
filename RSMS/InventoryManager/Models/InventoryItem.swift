import Foundation

// MARK: - ItemStatus
public enum ItemStatus: String, Codable, CaseIterable, Sendable {
    case available  = "Available"
    case reserved   = "Reserved"
    case inTransit  = "In Transit"
    case underRepair = "Under Repair"
    case scrapped   = "Scrapped"
    case sold       = "Sold"
}

// MARK: - AuthenticityStatus
public enum AuthenticityStatus: String, Codable, CaseIterable, Sendable {
    case verified = "Verified"
    case pending  = "Pending"
    case failed   = "Failed"
}


// MARK: - RepairStatus
public enum RepairStatus: String, Codable, CaseIterable, Sendable {
    case created   = "Created"
    case diagnosed = "Diagnosed"
    case inRepair  = "In Repair"
    case qaCheck   = "QA Check"
    case completed = "Completed"
    case failed    = "Failed"
    case scrapped  = "Scrapped"
}

// MARK: - RepairTicket
public struct RepairTicket: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var itemId: String
    public var issueType: String
    public var description: String
    public var status: RepairStatus
    public var assignedTo: String?
    public var eta: Date?
    public var createdAt: Date
    public var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case itemId       = "item_id"
        case issueType    = "issue_type"
        case description
        case status
        case assignedTo   = "assigned_to"
        case eta
        case createdAt    = "created_at"
        case updatedAt    = "updated_at"
    }

    // Custom decoder: handles Postgres date-only format "yyyy-MM-dd" for eta
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id          = try c.decode(UUID.self, forKey: .id)
        itemId      = try c.decode(String.self, forKey: .itemId)
        issueType   = try c.decode(String.self, forKey: .issueType)
        description = try c.decode(String.self, forKey: .description)
        status      = try c.decode(RepairStatus.self, forKey: .status)
        assignedTo  = try? c.decodeIfPresent(String.self, forKey: .assignedTo)
        createdAt   = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()
        updatedAt   = (try? c.decode(Date.self, forKey: .updatedAt)) ?? Date()

        if let date = try? c.decodeIfPresent(Date.self, forKey: .eta) {
            eta = date
        } else if let etaStr = try? c.decodeIfPresent(String.self, forKey: .eta) {
            let df = DateFormatter()
            df.dateFormat = "yyyy-MM-dd"
            eta = df.date(from: etaStr ?? "")
        } else {
            eta = nil
        }
    }

    public init(
        id: UUID = UUID(),
        itemId: String,
        issueType: String,
        description: String,
        status: RepairStatus = .created,
        assignedTo: String? = nil,
        eta: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.itemId = itemId
        self.issueType = issueType
        self.description = description
        self.status = status
        self.assignedTo = assignedTo
        self.eta = eta
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - ScanStatus
public enum ScanStatus: Sendable {
    case ok       // Scanned within the frequency window
    case dueSoon  // < 6 hours until nextScanDueAt
    case overdue  // now > nextScanDueAt, or never scanned

    public var label: String {
        switch self {
        case .ok:      return "OK"
        case .dueSoon: return "Due Soon"
        case .overdue: return "Overdue"
        }
    }
}

// MARK: - InventoryItem
public struct InventoryItem: Identifiable, Codable, Hashable, Sendable {
    public var id: String           // RFID Tag (e.g., RFID-9001)
    public var serialId: String
    public var productId: UUID
    public var batchNo: String
    public var certificateId: String?
    public var productName: String
    public var category: String
    public var location: String
    public var status: ItemStatus
    public var activeTicket: RepairTicket?
    public var timestamp: Date

    // Cycle-count / audit fields
    public var lastScannedAt: Date?
    public var nextScanDueAt: Date?
    public var scanFrequencyHours: Int
    public var lastAuditSessionId: UUID?
    public var isFlaggedMissing: Bool
    public var scanCount: Int

    // Certification fields
    public var assetTag: String?           // Human-readable ID (e.g. RSMS-2024-001)
    public var certificationIds: [UUID]    // Linked certificates
    public var authenticityStatus: AuthenticityStatus


    // MARK: CodingKeys
    enum CodingKeys: String, CodingKey {
        case id
        case serialId           = "serial_id"
        case productId          = "product_id"
        case batchNo            = "batch_no"
        case certificateId      = "certificate_id"
        case productName        = "product_name"
        case category
        case location
        case status
        case activeTicket       = "active_ticket"
        case timestamp
        case lastScannedAt      = "last_scanned_at"
        case nextScanDueAt      = "next_scan_due_at"
        case scanFrequencyHours = "scan_frequency_hours"
        case lastAuditSessionId = "last_audit_session_id"
        case isFlaggedMissing   = "is_flagged_missing"
        case scanCount          = "scan_count"
        case assetTag           = "asset_tag"
        case certificationIds   = "certification_ids"
        case authenticityStatus = "authenticity_status"
    }


    // MARK: Memberwise init
    public init(
        id: String,
        serialId: String,
        productId: UUID,
        batchNo: String,
        certificateId: String? = nil,
        productName: String,
        category: String,
        location: String,
        status: ItemStatus,
        activeTicket: RepairTicket? = nil,
        timestamp: Date = Date(),
        lastScannedAt: Date? = nil,
        nextScanDueAt: Date? = nil,
        scanFrequencyHours: Int = 48,
        lastAuditSessionId: UUID? = nil,
        isFlaggedMissing: Bool = false,
        scanCount: Int = 0,
        assetTag: String? = nil,
        certificationIds: [UUID] = [],
        authenticityStatus: AuthenticityStatus = .pending
    ) {

        self.id = id
        self.serialId = serialId
        self.productId = productId
        self.batchNo = batchNo
        self.certificateId = certificateId
        self.productName = productName
        self.category = category
        self.location = location
        self.status = status
        self.activeTicket = activeTicket
        self.timestamp = timestamp
        self.lastScannedAt = lastScannedAt
        self.nextScanDueAt = nextScanDueAt
        self.scanFrequencyHours = scanFrequencyHours
        self.lastAuditSessionId = lastAuditSessionId
        self.isFlaggedMissing = isFlaggedMissing
        self.scanCount = scanCount
        self.assetTag = assetTag
        self.certificationIds = certificationIds
        self.authenticityStatus = authenticityStatus
    }


    // MARK: Failable decoder (all new fields get safe defaults so old DB rows still decode)
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id              = try c.decode(String.self, forKey: .id)
        serialId        = (try? c.decode(String.self,  forKey: .serialId))    ?? ""
        productId       = (try? c.decode(UUID.self,    forKey: .productId))   ?? UUID()
        batchNo         = (try? c.decode(String.self,  forKey: .batchNo))     ?? ""
        certificateId   = try? c.decodeIfPresent(String.self, forKey: .certificateId)
        productName     = (try? c.decode(String.self,  forKey: .productName)) ?? ""
        category        = (try? c.decode(String.self,  forKey: .category))    ?? ""
        location        = (try? c.decode(String.self,  forKey: .location))    ?? ""
        status          = (try? c.decode(ItemStatus.self, forKey: .status))   ?? .available
        activeTicket    = try? c.decodeIfPresent(RepairTicket.self, forKey: .activeTicket)
        timestamp       = (try? c.decode(Date.self, forKey: .timestamp))      ?? Date()
        lastScannedAt   = try? c.decodeIfPresent(Date.self, forKey: .lastScannedAt)
        nextScanDueAt   = try? c.decodeIfPresent(Date.self, forKey: .nextScanDueAt)
        scanFrequencyHours = (try? c.decodeIfPresent(Int.self, forKey: .scanFrequencyHours)) ?? 48
        lastAuditSessionId = try? c.decodeIfPresent(UUID.self, forKey: .lastAuditSessionId)
        isFlaggedMissing   = (try? c.decodeIfPresent(Bool.self, forKey: .isFlaggedMissing)) ?? false
        scanCount          = (try? c.decodeIfPresent(Int.self,  forKey: .scanCount)) ?? 0
        assetTag           = try? c.decodeIfPresent(String.self, forKey: .assetTag)
        certificationIds   = (try? c.decodeIfPresent([UUID].self, forKey: .certificationIds)) ?? []
        authenticityStatus = (try? c.decodeIfPresent(AuthenticityStatus.self, forKey: .authenticityStatus)) ?? .pending
    }


    // MARK: Derived: ScanStatus
    public var scanStatus: ScanStatus {
        // Items under repair / scrapped / sold are exempt from cycle-count SLA
        if status == .underRepair || status == .scrapped || status == .sold { return .ok }

        guard let due = nextScanDueAt else {
            return lastScannedAt == nil ? .overdue : .ok
        }
        let now = Date()
        if now > due { return .overdue }
        if due.timeIntervalSince(now) < 6 * 3600 { return .dueSoon }
        return .ok
    }

    /// Recalculate nextScanDueAt from lastScannedAt + scanFrequencyHours
    public mutating func refreshScanDue() {
        guard let last = lastScannedAt else {
            nextScanDueAt = nil
            return
        }
        nextScanDueAt = last.addingTimeInterval(Double(scanFrequencyHours) * 3600)
    }
}
