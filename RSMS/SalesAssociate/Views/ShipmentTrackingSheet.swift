import SwiftUI
import Supabase

struct ShipmentTrackingSheet: View {
    let orderId: UUID
    let shippingStatus: String
    @ObservedObject var shippingViewModel: CustomerShippingViewModel
    
    @Environment(\.dismiss) var dismiss
    @State private var returnLog: CustomerShippingViewModel.ReturnLogEntry?
    @State private var isLoading = true
    @State private var pulseScale: CGFloat = 1.0
    
    // Checkpoints definitions
    private var checkpoints: [(id: String, label: String, icon: String)] {
        let base = [
            ("accepted", "Order Accepted", "shippingbox.fill"),
            ("picked_up", "Picked Up", "box.truck.fill"),
            ("in_transit", "In Transit", "airplane"),
            ("out_for_delivery", "Out for Delivery", "person.and.arrow.left.and.arrow.right")
        ]
        
        if shippingStatus == "returned" {
            return base + [
                ("return_initiated", "Return Initiated", "exclamationmark.arrow.triangle.2.circlepath"),
                ("returned_to_store", "Returned to Store", "arrow.uturn.backward.circle.fill")
            ]
        } else {
            var full = base + [("delivered", "Delivered", "checkmark.seal.fill")]
            // Add COD steps if relevant
            if let shipment = shippingViewModel.shipment, shipment.status == "cod_collected" || shipment.status == "cod_remitted" {
                full.append(("cod_collected", "Payment Collected", "indianrupeesign.circle.fill"))
                full.append(("cod_remitted", "Payment Settled", "banknote.fill"))
            }
            return full
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                BoutiqueTheme.background.ignoresSafeArea()
                
                if isLoading {
                    ProgressView()
                        .tint(BoutiqueTheme.primary)
                } else if let shipment = shippingViewModel.shipment {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 24) {
                            headerSection(shipment: shipment)
                            
                            timelineSection(shipment: shipment)
                            
                            bottomSection(shipment: shipment)
                            
                            Spacer(minLength: 40)
                        }
                        .padding(.vertical, 24)
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "shippingbox")
                            .font(.system(size: 48))
                            .foregroundStyle(BoutiqueTheme.mutedText)
                        Text("No shipment data available")
                            .font(BrandFont.body(16, weight: .medium))
                            .foregroundStyle(BoutiqueTheme.secondaryText)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 8) {
                        Text("Shipment Tracking")
                            .font(.system(size: 18, weight: .bold, design: .serif))
                            .foregroundStyle(BoutiqueTheme.primaryText)
                        
                        // Live indicator
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                            .opacity(pulseScale)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(BoutiqueTheme.primary)
                }
            }
            .task {
                await shippingViewModel.fetchShipment(for: orderId)
                if shippingStatus == "returned" {
                    returnLog = await shippingViewModel.fetchReturnLog(for: orderId)
                }
                shippingViewModel.subscribeToShipmentUpdates(for: orderId)
                isLoading = false
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                    pulseScale = 0.3
                }
            }
        }
    }
    
    // MARK: - Sections
    
    private func headerSection(shipment: CustomerShippingViewModel.OrderShipment) -> some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AWB: \(shipment.awbNumber ?? "TBA")")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(BoutiqueTheme.secondaryText)
                    Text(shipment.courierName ?? "RSMS Simulator")
                        .font(BrandFont.body(14))
                        .foregroundStyle(BoutiqueTheme.mutedText)
                }
                Spacer()
                statusBadge(status: shipment.status)
            }
            
            if let est = shipment.estimatedDelivery {
                Divider().background(BoutiqueTheme.divider)
                HStack {
                    Text("Est. Delivery: \(formattedDate(est))")
                        .font(BrandFont.body(13, weight: .medium))
                        .foregroundStyle(BoutiqueTheme.primaryText)
                    Spacer()
                }
            }
        }
        .padding(20)
        .boutiqueCardChrome()
        .padding(.horizontal, 16)
    }
    
    private func timelineSection(shipment: CustomerShippingViewModel.OrderShipment) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(checkpoints.enumerated()), id: \.offset) { index, checkpoint in
                timelineRow(
                    checkpoint: checkpoint,
                    shipment: shipment,
                    isLast: index == checkpoints.count - 1
                )
            }
        }
        .padding(24)
        .boutiqueCardChrome()
        .padding(.horizontal, 16)
    }
    
    private func bottomSection(shipment: CustomerShippingViewModel.OrderShipment) -> some View {
        VStack(spacing: 16) {
            // Order Summary Card
            VStack(alignment: .leading, spacing: 12) {
                Text("ORDER SUMMARY")
                    .font(.system(size: 10, weight: .bold))
                    .kerning(1.2)
                    .foregroundStyle(BoutiqueTheme.mutedText)
                
                HStack {
                    Text("Order ID")
                        .font(BrandFont.body(13))
                        .foregroundStyle(BoutiqueTheme.secondaryText)
                    Spacer()
                    Text(orderId.uuidString.prefix(8) + "...")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(BoutiqueTheme.primaryText)
                }
                
                if shippingStatus == "returned", let log = returnLog {
                    Divider().background(BoutiqueTheme.divider)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Return Initiated")
                            .font(BrandFont.body(14, weight: .bold))
                            .foregroundStyle(Color.red)
                        
                        Text(log.returnReason)
                            .font(BrandFont.body(13))
                            .foregroundStyle(BoutiqueTheme.secondaryText)
                        
                        HStack {
                            Text(log.condition.capitalized)
                                .font(.system(size: 10, weight: .bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(BoutiqueTheme.surface)
                                .foregroundStyle(BoutiqueTheme.deepAccent)
                                .clipShape(Capsule())
                            
                            Text("Awaiting Manager Inspection")
                                .font(BrandFont.body(11, weight: .regular).italic())
                                .foregroundStyle(BoutiqueTheme.mutedText)
                        }
                    }
                }
            }
            .padding(20)
            .boutiqueCardChrome()
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - Components
    
    private func timelineRow(checkpoint: (id: String, label: String, icon: String), shipment: CustomerShippingViewModel.OrderShipment, isLast: Bool) -> some View {
        let (isCompleted, isCurrent) = getStatusState(checkpointId: checkpoint.id, currentStatus: shipment.status)
        let isRed = shippingStatus == "returned" && (checkpoint.id == "return_initiated" || checkpoint.id == "returned_to_store")
        
        return HStack(alignment: .top, spacing: 16) {
            // Left: Indicator and Line
            VStack(spacing: 0) {
                ZStack {
                    if isCurrent {
                        Circle()
                            .stroke(isRed ? Color.red.opacity(0.22) : BoutiqueTheme.primary.opacity(0.22), lineWidth: 3)
                            .frame(width: 18, height: 18)
                    }
                    
                    Circle()
                        .fill(isCompleted || isCurrent ? (isRed ? Color.red : BoutiqueTheme.primary) : Color.clear)
                        .frame(width: 10, height: 10)
                        .overlay(
                            Circle().stroke(isCompleted || isCurrent ? Color.clear : Color.gray.opacity(0.3), lineWidth: 1)
                        )
                }
                
                if !isLast {
                    if isCompleted {
                        Rectangle()
                            .fill(isRed ? Color.red : BoutiqueTheme.primary)
                            .frame(width: 2)
                            .frame(minHeight: 40)
                    } else {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(width: 2)
                            .frame(minHeight: 40)
                            .overlay(
                                Path { path in
                                    path.move(to: CGPoint(x: 1, y: 0))
                                    path.addLine(to: CGPoint(x: 1, y: 40))
                                }
                                .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [4, 4]))
                            )
                    }
                }
            }
            
            // Right: Text Content
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: checkpoint.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(isCompleted || isCurrent ? (isRed ? Color.red : BoutiqueTheme.primary) : BoutiqueTheme.mutedText)
                    
                    Text(checkpoint.label)
                        .font(BrandFont.body(14, weight: isCurrent ? .bold : (isCompleted ? .semibold : .regular)))
                        .foregroundStyle(isCompleted || isCurrent ? BoutiqueTheme.primaryText : BoutiqueTheme.mutedText)
                }
                
                if isCurrent {
                    Text("In Progress...")
                        .font(BrandFont.body(11, weight: .medium).italic())
                        .foregroundStyle(BoutiqueTheme.mutedText)
                }
            }
            .padding(.top, -2)
            
            Spacer()
        }
    }
    
    private func statusBadge(status: String) -> some View {
        let text = status.replacingOccurrences(of: "_", with: " ").capitalized
        let color: Color
        
        switch status.lowercased() {
        case "accepted", "picked_up": color = Color.blue
        case "in_transit": color = Color.purple
        case "out_for_delivery": color = Color.orange
        case "delivered": color = Color.green
        case "cod_collected": color = Color.orange
        case "cod_remitted": color = Color.green
        case "returned": color = Color.red
        default: color = BoutiqueTheme.secondaryText
        }
        
        return Text(text)
            .font(.system(size: 11, weight: .bold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
    
    // MARK: - Helpers
    
    private func getStatusState(checkpointId: String, currentStatus: String) -> (isCompleted: Bool, isCurrent: Bool) {
        let status = currentStatus.lowercased()
        let id = checkpointId.lowercased()
        
        let order = ["accepted", "picked_up", "in_transit", "out_for_delivery", "delivered", "cod_collected", "cod_remitted"]
        let returnOrder = ["accepted", "picked_up", "in_transit", "out_for_delivery", "return_initiated", "returned_to_store"]
        
        let activeOrder = shippingStatus == "returned" ? returnOrder : order
        
        guard let currentIndex = activeOrder.firstIndex(of: status),
              let checkIndex = activeOrder.firstIndex(of: id) else {
            return (false, false)
        }
        
        if checkIndex < currentIndex {
            return (true, false)
        } else if checkIndex == currentIndex {
            return (true, true)
        } else {
            return (false, false)
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy"
        return formatter.string(from: date)
    }
}
