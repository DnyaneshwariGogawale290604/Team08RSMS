import Foundation

public enum ExceptionType: String, Codable {
    case missing = "Missing Item"
    case duplicate = "Duplicate Scan"
    case mismatch = "Location Mismatch"
    case certificationMissing = "Missing Certification"
    case certificationExpired = "Expired Certification"
}


public enum ExceptionSeverity: String, Codable {
    case high = "High"       // Missing items
    case medium = "Medium"     // Location mismatches
    case low = "Low"          // Duplicate scans
    
    public var sortWeight: Int {
        switch self {
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
}

public enum ExceptionResolutionAction {
    case markFound
    case confirmMissing
    case updateLocation
    case ignoreDuplicate
    case uploadCertificate
    case renewCertificate
}


public struct ExceptionRecord: Identifiable {
    public let id = UUID()
    public let rfid: String
    public let expectedLocation: String?
    public let scannedLocation: String?
    public let type: ExceptionType
    public let severity: ExceptionSeverity
    public let timestamp: Date
    
    // Optional: The actual database item if we have it
    public var item: InventoryItem?
    public var isResolved: Bool = false
    
    public init(rfid: String, type: ExceptionType, severity: ExceptionSeverity, expectedLocation: String? = nil, scannedLocation: String? = nil, item: InventoryItem? = nil) {
        self.rfid = rfid
        self.type = type
        self.severity = severity
        self.expectedLocation = expectedLocation
        self.scannedLocation = scannedLocation
        self.item = item
        self.timestamp = Date()
    }
}
