import Foundation
import SwiftUI
import Combine

@MainActor
public class BoutiqueSalesViewModel: ObservableObject {
    @Published public var salesList: [SalesOrder] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?

    public init() {}

    public func fetchSales() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                self.salesList = try await DataService.shared.fetchSales(storeId: nil)
                self.isLoading = false
            } catch {
                self.errorMessage = "Failed to load sales data from Supabase."
                self.isLoading = false
            }
        }
    }

    public var totalRevenue: Double {
        salesList.reduce(0) { $0 + $1.totalAmount }
    }
}
