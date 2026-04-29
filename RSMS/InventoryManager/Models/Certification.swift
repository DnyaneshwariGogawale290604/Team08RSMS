import Foundation

public enum CertificationStatus: String, Codable, CaseIterable, Sendable {
    case valid   = "Valid"
    case expired = "Expired"
    case revoked = "Revoked"
}

public struct Certification: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let itemId: String // RFID Tag
    public var type: String
    public var certificateNumber: String
    public var issuedBy: String
    public var issuedDate: Date
    public var expiryDate: Date?
    public var documentURL: String?
    public var status: CertificationStatus
    public var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case itemId           = "item_id"
        case type
        case certificateNumber = "certificate_number"
        case issuedBy         = "issued_by"
        case issuedDate       = "issued_date"
        case expiryDate       = "expiry_date"
        case documentURL      = "document_url"
        case status
        case createdAt        = "created_at"
    }

    public init(
        id: UUID = UUID(),
        itemId: String,
        type: String,
        certificateNumber: String,
        issuedBy: String,
        issuedDate: Date,
        expiryDate: Date? = nil,
        documentURL: String? = nil,
        status: CertificationStatus = .valid,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.itemId = itemId
        self.type = type
        self.certificateNumber = certificateNumber
        self.issuedBy = issuedBy
        self.issuedDate = issuedDate
        self.expiryDate = expiryDate
        self.documentURL = documentURL
        self.status = status
        self.createdAt = createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id                = try c.decode(UUID.self, forKey: .id)
        itemId            = try c.decode(String.self, forKey: .itemId)
        type              = (try? c.decode(String.self, forKey: .type)) ?? "Standard"
        certificateNumber = (try? c.decode(String.self, forKey: .certificateNumber)) ?? "N/A"
        issuedBy          = (try? c.decode(String.self, forKey: .issuedBy)) ?? "Unknown"
        status            = (try? c.decode(CertificationStatus.self, forKey: .status)) ?? .valid
        documentURL       = try? c.decodeIfPresent(String.self, forKey: .documentURL)
        createdAt         = (try? c.decode(Date.self, forKey: .createdAt)) ?? Date()

        // Handle date strings or dates
        if let iDate = try? c.decode(Date.self, forKey: .issuedDate) {
            issuedDate = iDate
        } else if let dateStr = try? c.decode(String.self, forKey: .issuedDate) {
            issuedDate = Certification.dateFormatter.date(from: dateStr) ?? Date()
        } else {
            issuedDate = Date()
        }

        if let eDate = try? c.decodeIfPresent(Date.self, forKey: .expiryDate) {
            expiryDate = eDate
        } else if let dateStr = try? c.decodeIfPresent(String.self, forKey: .expiryDate) {
            expiryDate = Certification.dateFormatter.date(from: dateStr)
        } else {
            expiryDate = nil
        }
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}
