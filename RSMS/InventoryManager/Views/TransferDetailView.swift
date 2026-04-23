import SwiftUI

public struct TransferDetailView: View {
    public let transfer: Transfer
    @ObservedObject private var engine = InventoryEngine.shared
    @State private var inputVendorId: String = ""
    @State private var inputVendorContact: String = ""
    @State private var showingSerialization = false
    
    public init(transfer: Transfer) {
        self.transfer = transfer
    }
    
    public var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    ReusableCardView {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Order ID: \(transfer.orderId)")
                                    .font(.headline)
                                    .foregroundColor(.appPrimaryText)
                                Spacer()
                                Text(transfer.status.rawValue)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(statusColor(transfer.status))
                                    .cornerRadius(20)
                            }
                            Divider().background(Color.appBorder)
                            
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("From")
                                        .font(.caption)
                                        .foregroundColor(.appSecondaryText)
                                    Text(transfer.fromLocation)
                                        .font(.subheadline)
                                        .foregroundColor(.appPrimaryText)
                                }
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.appSecondaryText)
                                Spacer()
                                VStack(alignment: .trailing) {
                                    Text("To")
                                        .font(.caption)
                                        .foregroundColor(.appSecondaryText)
                                    Text(transfer.toLocation)
                                        .font(.subheadline)
                                        .foregroundColor(.appPrimaryText)
                                }
                            }
                            
                            // Placed Vendor Details
                            if transfer.status != .pending && transfer.status != .approved && transfer.type == .vendor, let vendorId = transfer.vendorId, let vendorContact = transfer.vendorContactInfo {
                                Divider().background(Color.appBorder)
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Supplier Details")
                                        .font(.caption)
                                        .foregroundColor(.appSecondaryText)
                                    Text(vendorId)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.appPrimaryText)
                                    Text(vendorContact)
                                        .font(.caption)
                                        .foregroundColor(.appSecondaryText)
                                    if let vendorOrderId = transfer.vendorOrderId {
                                        Text("Ref: \(vendorOrderId)")
                                            .font(.caption.italic())
                                            .foregroundColor(.appSecondaryText)
                                    }
                                }
                            }
                            
                            Divider().background(Color.appBorder)
                            
                            HStack {
                                Text("Batch No:")
                                    .font(.subheadline)
                                    .foregroundColor(.appSecondaryText)
                                Spacer()
                                Text(transfer.batchNumber)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.appPrimaryText)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)
                    
                    // Admin Notes / Rejection Reason (IM-4)
                    if let reason = transfer.adminActionReason {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Admin Decision")
                                .font(.title3.bold())
                                .foregroundColor(.appPrimaryText)
                                .padding(.horizontal)
                            
                            ReusableCardView {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: transfer.status == .rejected ? "xmark.octagon.fill" : "checkmark.seal.fill")
                                            .foregroundColor(transfer.status == .rejected ? .red : .green)
                                        Text(transfer.status == .rejected ? "Rejected" : "Approved")
                                            .font(.subheadline.bold())
                                            .foregroundColor(.appPrimaryText)
                                        Spacer()
                                        if let updatedDate = transfer.statusUpdatedAt {
                                            Text(updatedDate, style: .date)
                                                .font(.caption)
                                                .foregroundColor(.appSecondaryText)
                                        }
                                    }
                                    Divider()
                                    Text("Reason: \(reason)")
                                        .font(.subheadline)
                                        .foregroundColor(.appSecondaryText)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Specific shipment of order status section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Shipment Status")
                            .font(.title3.bold())
                            .foregroundColor(.appPrimaryText)
                            .padding(.horizontal)
                        
                        ReusableCardView {
                            VStack(spacing: 0) {
                                timelineStep(title: "Pending", isCompleted: transfer.status != .pending, isLast: false)
                                timelineStep(title: "Dispatched", isCompleted: transfer.status == .dispatched || transfer.status == .inTransit || transfer.status == .delivered, isLast: false)
                                timelineStep(title: "In Transit", isCompleted: transfer.status == .inTransit || transfer.status == .delivered, isLast: false)
                                timelineStep(title: "Delivered", isCompleted: transfer.status == .delivered, isLast: true)
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Receipt of order -> list of items
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Receipt of Order")
                            .font(.title3.bold())
                            .foregroundColor(.appPrimaryText)
                            .padding(.horizontal)
                        
                        LazyVStack(spacing: 12) {
                            ForEach(transfer.items) { item in
                                ReusableCardView {
                                    HStack {
                                        Text(item.productName)
                                            .font(.body)
                                            .foregroundColor(.appPrimaryText)
                                        Spacer()
                                        
                                        if transfer.type == .boutique && transfer.status == .pending {
                                            let availableCount = engine.getStock(sku: item.productName, location: transfer.fromLocation)
                                            Text("Avail: \(availableCount)")
                                                .font(.caption.bold())
                                                .foregroundColor(availableCount >= item.quantity ? .green : .red)
                                                .padding(.trailing, 4)
                                        }
                                        Text("Qty: \(item.quantity)")
                                            .font(.subheadline.bold())
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 4)
                                            .background(Color.appBorder.opacity(0.3))
                                            .cornerRadius(20)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                    }
                    
                    // IM-6 & IM-7: Action Panel for Inventory Manager
                    actionPanel
                        .padding(.horizontal)
                        .padding(.top, 10)
                }
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Transfer Details")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingSerialization) {
            BatchSerializationView(transfer: transfer)
        }
    }
    
    @ViewBuilder
    private var actionPanel: some View {
        VStack(spacing: 16) {
            if transfer.type == .vendor && transfer.status == .approved {
                // IM-??: Procurement Initiation Module
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "cart.badge.plus")
                            .foregroundColor(.appAccent)
                        Text("Initiate Procurement")
                            .font(.headline)
                            .foregroundColor(.appPrimaryText)
                        Spacer()
                    }
                    
                    TextField("Enter Vendor ID (e.g. Aurum Global)", text: $inputVendorId)
                        .padding(12)
                        .background(Color.appBackground)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1))
                        
                    TextField("Contact Email / Phone", text: $inputVendorContact)
                        .padding(12)
                        .background(Color.appBackground)
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1))
                        
                    Button(action: {
                        InventoryEngine.shared.placeVendorOrder(transferId: transfer.id, vendorId: inputVendorId, contactInfo: inputVendorContact)
                    }) {
                        Text("Place Vendor Order")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(inputVendorId.isEmpty || inputVendorContact.isEmpty)
                }
                .padding()
                .appCardChrome()
            } else if transfer.status == .placed || (transfer.type == .boutique && transfer.status == .approved) || transfer.status == .pending {
                let hasSufficientStock = transfer.items.allSatisfy { item in
                    engine.getStock(sku: item.productName, location: transfer.fromLocation) >= item.quantity
                }
                
                Button(action: {
                    Task { await InventoryEngine.shared.updateTransferStatus(transferId: transfer.id, newStatus: .dispatched) }
                }) {
                    Text(transfer.type == .vendor ? "Vendor Dispatched Transport" : "Call Transport (Dispatch)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background((transfer.type == .boutique && !hasSufficientStock) ? Color.gray : (transfer.type == .vendor ? Color.blue : Color.orange))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .disabled(transfer.type == .boutique && !hasSufficientStock)
            } else if transfer.status == .dispatched {
                Button(action: {
                    Task { await InventoryEngine.shared.updateTransferStatus(transferId: transfer.id, newStatus: .inTransit) }
                }) {
                    Text("Transport Arrived (Set In Transit)")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            } else if transfer.status == .inTransit {
                Button(action: {
                    showingSerialization = true
                }) {
                    Text("Ingest Batch & Receive")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
        }
    }
    
    @ViewBuilder
    private func timelineStep(title: String, isCompleted: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 15) {
            VStack(spacing: 0) {
                Circle()
                    .fill(isCompleted ? Color.appAccent : Color.appBorder)
                    .frame(width: 16, height: 16)
                if !isLast {
                    Rectangle()
                        .fill(isCompleted ? Color.appAccent : Color.appBorder)
                        .frame(width: 2, height: 30) // line connecting
                }
            }
            Text(title)
                .font(.subheadline)
                .foregroundColor(isCompleted ? .appPrimaryText : .appSecondaryText)
                .padding(.top, -2) // align text with circle
            Spacer()
        }
    }
    
    private func statusColor(_ status: TransferStatus) -> Color {
        switch status {
        case .pending, .approved: return .appAccent
        case .placed: return .blue
        case .dispatched, .inTransit: return .appPrimaryText
        case .delivered, .received: return .appSecondaryText
        case .returned, .rejected: return .red
        }
    }
}
