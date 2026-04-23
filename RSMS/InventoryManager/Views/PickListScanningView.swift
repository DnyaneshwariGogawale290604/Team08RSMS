import SwiftUI

public struct PickListScanningView: View {
    @StateObject private var viewModel = InventoryDashboardViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var demand: Transfer
    @State private var scannedRFIDs: [String] = []
    @State private var isScanning = false
    @State private var scanError: String?
    
    public init(demand: Transfer) {
        self.demand = demand
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            Text("Pick List: \(demand.orderId)")
                .font(.title2.bold())
            
            Text("Requested: \(demand.items.map { "\($0.quantity)x \($0.productName)" }.joined(separator: ", "))")
                .foregroundColor(.appSecondaryText)
            
            Divider()
            
            List {
                ForEach(scannedRFIDs, id: \.self) { rfid in
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(rfid)
                    }
                }
            }
            .listStyle(.plain)
            
            if let error = scanError {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
            
            HStack {
                Button(action: {
                    simulateScan()
                }) {
                    HStack {
                        Image(systemName: "sensor.tag.radiowaves.forward")
                        Text(isScanning ? "Scanning..." : "Simulate RFID Scan")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isScanning || scannedRFIDs.count >= totalRequiredQuantity())
                
                Button(action: {
                    Task {
                        await InventoryEngine.shared.fulfillPickList(demandId: demand.id, rfids: scannedRFIDs)
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    Text("Confirm & Dispatch")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(scannedRFIDs.count == totalRequiredQuantity() ? Color.green : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(scannedRFIDs.count != totalRequiredQuantity())
            }
            .padding()
        }
        .padding()
        .navigationTitle("Fulfill Request")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadDashboardData()
        }
    }
    
    private func totalRequiredQuantity() -> Int {
        return demand.items.map { $0.quantity }.reduce(0, +)
    }
    
    private func simulateScan() {
        isScanning = true
        scanError = nil
        
        // Find an item matching the demand that is available
        guard let itemNeeded = demand.items.first(where: { item in
            // Basic simplistic match
            scannedRFIDs.count < totalRequiredQuantity()
        }) else { return }
        
        // The simulation logic now checks real stock in the async block below
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            isScanning = false
            
            // Check real stock from Supabase instead of mock engine
            let productName = itemNeeded.productName
            let inventoryRows = viewModel.storeInventory
            let products = viewModel.products
            
            let matchedProducts = products.filter { $0.name == productName }
            let matchedProductIds = Set(matchedProducts.map { $0.id })
            
            let filteredInventory = inventoryRows.filter { inv in
                if let pid = inv.productId { return matchedProductIds.contains(pid) }
                return false
            }
            
            let totalAvailable = filteredInventory.reduce(0) { sum, inv in sum + inv.quantity }
            
            if scannedRFIDs.count < totalAvailable && scannedRFIDs.count < totalRequiredQuantity() {
                // In a real app, this would be an RFID tag ID. For simulation, we generate a unique one.
                let mockRFID = "SIM-RFID-\(productName.prefix(3).uppercased())-\(scannedRFIDs.count + 1)"
                scannedRFIDs.append(mockRFID)
            } else {
                scanError = "Insufficient Stock for \(productName)!"
            }
        }
    }
}
