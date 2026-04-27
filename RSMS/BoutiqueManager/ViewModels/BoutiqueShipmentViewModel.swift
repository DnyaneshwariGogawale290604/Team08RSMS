import Foundation
import Combine

@MainActor
public final class BoutiqueShipmentViewModel: ObservableObject {
    @Published public var incomingShipments: [Shipment] = []
    @Published public var allRequests: [ProductRequest] = []
    @Published public var receivedGRNs: [GoodsReceivedNote] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String? = nil
    @Published public var lastGeneratedGRN: String? = nil
    private var isReloading = false

    public init() {}

    // MARK: - Load

    public func loadAll() async {
        guard !isReloading else { return }
        isReloading = true
        isLoading = true
        defer {
            isReloading = false
            isLoading = false
        }

        do {
            errorMessage = nil

            // Keep shipment-tab reloads stable by avoiding overlapping parallel
            // Supabase reads for the same boutique session.
            let requests = try await RequestService.shared.fetchRequestsForCurrentBoutiqueStore()
            let shipments = try await RequestService.shared.fetchShipmentsForCurrentBoutiqueStore()
            let grns = try await RequestService.shared.fetchGRNsForCurrentBoutiqueStore()

            allRequests = requests
            incomingShipments = shipments
            receivedGRNs = grns
            errorMessage = nil
        } catch is CancellationError {
            // SwiftUI may cancel the in-flight load when the tab refreshes or
            // the view lifecycle changes. Keep the current data and suppress
            // the transient cancellation from surfacing as an error state.
        } catch {
            errorMessage = error.localizedDescription
            print("BoutiqueShipmentViewModel.loadAll error: \(error)")
        }
    }

    public func reorderRequest(request: ProductRequest) async {
        guard let productId = request.productId else { return }
        isLoading = true
        do {
            try await DataService.shared.createStockRequest(productId: productId, quantity: request.requestedQuantity)
            await loadAll()
        } catch {
            errorMessage = "Re-order failed: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Receive Goods → GRN

    public func receiveGoods(
        shipment: Shipment,
        quantityReceived: Int,
        condition: GoodsReceivedNote.GRNCondition,
        notes: String
    ) async -> String? {
        isLoading = true
        defer { isLoading = false }
        do {
            let grn = try await RequestService.shared.createGRN(
                shipmentId: shipment.id,
                requestId: shipment.requestId,
                quantityReceived: quantityReceived,
                condition: condition,
                notes: notes
            )
            lastGeneratedGRN = grn
            await loadAll()
            return grn
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    // MARK: - Helpers

    public func grn(forShipment shipment: Shipment) -> GoodsReceivedNote? {
        receivedGRNs.first(where: { $0.shipmentId == shipment.id })
    }

    public func hasGRN(forShipment shipment: Shipment) -> Bool {
        receivedGRNs.contains(where: { $0.shipmentId == shipment.id })
    }
}
