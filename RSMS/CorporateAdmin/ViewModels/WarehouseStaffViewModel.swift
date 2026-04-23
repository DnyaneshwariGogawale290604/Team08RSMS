import Foundation
import Combine

@MainActor
public final class WarehouseStaffViewModel: ObservableObject {
    @Published public var inventoryManagers: [InventoryManagerRecord] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    private let service = WarehouseService.shared
    private let warehouseId: UUID
    
    public init(warehouseId: UUID) {
        self.warehouseId = warehouseId
    }
    
    public func fetchStaff() async {
        isLoading = true
        do {
            self.inventoryManagers = try await service.fetchInventoryManagers(forWarehouse: warehouseId)
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
