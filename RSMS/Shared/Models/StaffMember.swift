import Foundation

public enum StaffRoleTab: String, CaseIterable, Sendable {
    case boutiqueManager = "Boutique Manager"
    case inventoryManager = "Inventory Manager"
    case vendor = "Vendor"

    public var assignmentLabel: String {
        switch self {
        case .boutiqueManager:
            return "Store"
        case .inventoryManager:
            return "Warehouse"
        case .vendor:
            return "Vendor"
        }
    }
}

public struct BoutiqueManagerRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var storeId: UUID
    public var corporateAdminId: UUID
    public var createdAt: String?
    public var user: User?
    public var store: Store?

    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case storeId = "store_id"
        case corporateAdminId = "corporate_admin_id"
        case createdAt = "created_at"
        case user = "users"
        case store = "stores"
    }
}

public struct InventoryManagerRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var warehouseId: UUID
    public var corporateAdminId: UUID
    public var createdAt: String?
    public var user: User?
    public var warehouse: Warehouse?

    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case warehouseId = "warehouse_id"
        case corporateAdminId = "corporate_admin_id"
        case createdAt = "created_at"
        case user = "users"
        case warehouse = "warehouses"
    }
}



public struct SalesAssociateRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var storeId: UUID
    public var boutiqueManagerId: UUID
    public var createdAt: String?
    public var user: User?

    enum CodingKeys: String, CodingKey {
        case id = "user_id"
        case storeId = "store_id"
        case boutiqueManagerId = "boutique_manager_id"
        case createdAt = "created_at"
        case user = "users"
    }
}

public struct StaffListItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let role: StaffRoleTab
    public let user: User
    public let assignmentId: UUID?
    public let assignmentName: String
    public let assignmentDetail: String

    public init(id: UUID, role: StaffRoleTab, user: User, assignmentId: UUID?, assignmentName: String, assignmentDetail: String) {
        self.id = id
        self.role = role
        self.user = user
        self.assignmentId = assignmentId
        self.assignmentName = assignmentName
        self.assignmentDetail = assignmentDetail
    }
}

public struct StaffCreationRequest: Sendable {
    public let role: StaffRoleTab
    public let employeeId: UUID
    public let name: String
    public let phone: String
    public let email: String
    public let password: String
    public let storeId: UUID?
    public let warehouseId: UUID?

    public init(
        role: StaffRoleTab,
        employeeId: UUID,
        name: String,
        phone: String,
        email: String,
        password: String,
        storeId: UUID? = nil,
        warehouseId: UUID? = nil
    ) {
        self.role = role
        self.employeeId = employeeId
        self.name = name
        self.phone = phone
        self.email = email
        self.password = password
        self.storeId = storeId
        self.warehouseId = warehouseId
    }
}
