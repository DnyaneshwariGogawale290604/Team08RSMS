import Foundation
import Combine

@MainActor
public final class StoreViewModel: ObservableObject {
    @Published public var stores: [Store] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    @Published public var storePerformance: [UUID: Double] = [:]
    @Published public var selectedTimeRange: String = "monthly"
    
    private let service = StoreService.shared
    
    public init() {}
    
    public func fetchStores() async {
        isLoading = true
        do {
            stores = try await service.fetchStores()
            
            var newPerformances: [UUID: Double] = [:]
            for store in stores {
                let performance = try? await service.fetchStoreSalesPerformance(storeId: store.id, timeRange: selectedTimeRange)
                newPerformances[store.id] = performance ?? 0
            }
            storePerformance = newPerformances
            
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    public func fetchStore(id: UUID) async throws -> Store {
        try await service.fetchStore(id: id)
    }
    
    public func updateStoreTarget(storeId: UUID, target: Double) async {
        isLoading = true
        do {
            try await service.updateStoreTarget(id: storeId, target: target)
            await fetchStores()
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    public func deleteStore(storeId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await service.deleteStore(id: storeId)
            await fetchStores()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func archiveStore(storeId: UUID) async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await service.archiveStore(id: storeId)
            await fetchStores()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
