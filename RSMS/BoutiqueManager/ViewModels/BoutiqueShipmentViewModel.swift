import Foundation
import Combine

@MainActor
public final class BoutiqueShipmentViewModel: ObservableObject {
    @Published public var incomingShipments: [Shipment] = []
    @Published public var receivedGRNs: [GoodsReceivedNote] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String? = nil
    @Published public var lastGeneratedGRN: String? = nil

    public init() {}

    // MARK: - Load

    public func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let shipmentsFetch = RequestService.shared.fetchShipmentsForCurrentBoutiqueStore()
            async let grnsFetch = RequestService.shared.fetchGRNsForCurrentBoutiqueStore()
            incomingShipments = try await shipmentsFetch
            receivedGRNs = try await grnsFetch
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            print("BoutiqueShipmentViewModel.loadAll error: \(error)")
        }
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
