import Foundation
import Combine

@MainActor
public final class StoreStaffViewModel: ObservableObject {
    @Published public var boutiqueManagers: [BoutiqueManagerRecord] = []
    @Published public var salesAssociates: [SalesAssociateRecord] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    private let service = StoreService.shared
    private let storeId: UUID
    
    public init(storeId: UUID) {
        self.storeId = storeId
    }
    
    public func fetchStaff() async {
        isLoading = true
        do {
            async let managersFetch = service.fetchBoutiqueManagers(forStore: storeId)
            async let associatesFetch = service.fetchSalesAssociates(forStore: storeId)
            
            let (managers, associates) = try await (managersFetch, associatesFetch)
            
            self.boutiqueManagers = managers
            self.salesAssociates = associates
            self.errorMessage = nil
        } catch {
            self.errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}
