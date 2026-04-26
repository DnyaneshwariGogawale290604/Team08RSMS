import Foundation
import Combine

@MainActor
public final class WarehouseViewModel: ObservableObject {
    @Published public var warehouses: [Warehouse] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    nonisolated(unsafe) private let service = WarehouseService.shared
    
    public init() {}
    
    public func fetchWarehouses() async {
        isLoading = true
        do {
            warehouses = try await service.fetchWarehouses()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    public func createWarehouse(_ warehouse: Warehouse) async {
        isLoading = true
        do {
            try await service.createWarehouse(warehouse)
            await fetchWarehouses()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    public func assignManager(warehouseId: UUID, managerId: UUID) async {
        do {
            try await service.assignInventoryManager(warehouseId: warehouseId, managerId: managerId)
            await fetchWarehouses()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func toggleWarehouseStatus(warehouseId: UUID, currentStatus: String?) async {
        let newStatus = (currentStatus == "active") ? "inactive" : "active"
        do {
            try await service.updateWarehouseStatus(id: warehouseId, status: newStatus)
            // No need to fetch all, just find and update locally for immediate feedback
            if let index = warehouses.firstIndex(where: { $0.id == warehouseId }) {
                warehouses[index].status = newStatus
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func archiveWarehouse(warehouseId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await service.archiveWarehouse(id: warehouseId)
            await fetchWarehouses()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
