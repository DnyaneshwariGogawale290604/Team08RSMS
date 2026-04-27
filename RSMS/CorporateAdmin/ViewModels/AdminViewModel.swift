import Foundation
import Combine

@MainActor
public final class AdminViewModel: ObservableObject {
    @Published public var selectedRole: StaffRoleTab = .boutiqueManager
    @Published public var boutiqueManagers: [StaffListItem] = []
    @Published public var inventoryManagers: [StaffListItem] = []
    @Published public var vendors: [Vendor] = []
    @Published public var vendorProductIdsByVendor: [UUID: Set<UUID>] = [:]
    @Published public var products: [Product] = []
    @Published public var stores: [Store] = []
    @Published public var warehouses: [Warehouse] = []
    @Published public var pendingVendorOrders: [VendorOrder] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    @Published public var successMessage: String?

    public var nextEmployeeNumber: String {
        let total = boutiqueManagers.count + inventoryManagers.count + 1
        return String(format: "%06d", total)
    }

    public var availableStores: [Store] {
        let assignedStoreIds = Set(boutiqueManagers.compactMap { $0.assignmentId })
        return stores.filter { !assignedStoreIds.contains($0.id) }
    }

    public var availableWarehouses: [Warehouse] {
        let assignedWarehouseIds = Set(inventoryManagers.compactMap { $0.assignmentId })
        return warehouses.filter { !assignedWarehouseIds.contains($0.id) }
    }

    private let service = AdminService.shared

    public init() {}

    public var visibleStaff: [StaffListItem] {
        switch selectedRole {
        case .boutiqueManager:
            return boutiqueManagers
        case .inventoryManager:
            return inventoryManagers
        case .vendor:
            return []
        }
    }

    public func loadInitialData() async {
        await fetchStores()
        await fetchWarehouses()
        await fetchProducts()
        await fetchStaff(for: selectedRole)
        await fetchPendingVendorOrders()
    }

    public func fetchStaff(for role: StaffRoleTab) async {
        selectedRole = role
        isLoading = true
        defer { isLoading = false }

        do {
            switch role {
            case .boutiqueManager:
                let rows = try await service.fetchBoutiqueManagers()
                boutiqueManagers = rows.compactMap { row in
                    guard let user = row.user else { return nil }
                    return StaffListItem(
                        id: row.id,
                        role: .boutiqueManager,
                        user: user,
                        assignmentId: row.storeId,
                        assignmentName: row.store?.displayName ?? "Unassigned Store",
                        assignmentDetail: row.store?.location ?? "No location"
                    )
                }

            case .inventoryManager:
                let rows = try await service.fetchInventoryManagers()
                inventoryManagers = rows.compactMap { row in
                    guard let user = row.user else { return nil }
                    return StaffListItem(
                        id: row.id,
                        role: .inventoryManager,
                        user: user,
                        assignmentId: row.warehouseId,
                        assignmentName: row.warehouse?.displayLabel ?? "Unassigned Warehouse",
                        assignmentDetail: row.warehouse?.location ?? "No location"
                    )
                }

            case .vendor:
                vendors = try await service.fetchVendors()
                var map: [UUID: Set<UUID>] = [:]
                for vendor in vendors {
                    map[vendor.id] = try await service.fetchVendorProductIds(vendorId: vendor.id)
                }
                vendorProductIdsByVendor = map
            }

            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func fetchStores() async {
        do {
            stores = try await service.fetchStores()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func fetchWarehouses() async {
        do {
            warehouses = try await service.fetchWarehouses()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func fetchProducts() async {
        do {
            products = try await service.fetchProductsForCurrentBrand()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func createStaffMember(_ request: StaffCreationRequest) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            try await service.createStaffMember(request)
            
            // Send welcome email to the new staff member via Resend
            try? await AuthService.shared.sendWelcomeEmail(
                email: request.email,
                name: request.name,
                password: request.password,
                role: request.role.rawValue
            )
            
            successMessage = "\(request.role.rawValue) created successfully. A welcome email has been sent."
            errorMessage = nil
            await fetchStaff(for: request.role)
            return true
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
            return false
        }
    }

    public func createVendor(name: String, contactInfo: String, productIds: Set<UUID>) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            try await service.createVendor(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                contactInfo: contactInfo.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : contactInfo.trimmingCharacters(in: .whitespacesAndNewlines),
                productIds: productIds
            )
            successMessage = "Vendor created successfully."
            errorMessage = nil
            await fetchStaff(for: .vendor)
            return true
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
            return false
        }
    }

    public func saveVendorProducts(vendorId: UUID, selectedProductIds: Set<UUID>) async -> Bool {
        isLoading = true
        defer { isLoading = false }

        do {
            try await service.syncVendorProducts(vendorId: vendorId, selectedProductIds: selectedProductIds)
            vendorProductIdsByVendor[vendorId] = selectedProductIds
            successMessage = "Vendor products updated successfully."
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            successMessage = nil
            return false
        }
    }

    // MARK: - Vendor Orders

    public func fetchPendingVendorOrders() async {
        do {
            pendingVendorOrders = try await RequestService.shared.fetchPendingVendorOrdersForAdmin()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func approveVendorOrder(id: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await RequestService.shared.approveVendorOrder(id: id)
            await fetchPendingVendorOrders()
            successMessage = "Vendor Order Approved."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    public func rejectVendorOrder(id: UUID, reason: String) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await RequestService.shared.updateVendorOrderStatus(id: id, status: "rejected")
            await fetchPendingVendorOrders()
            successMessage = "Vendor Order Rejected."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
