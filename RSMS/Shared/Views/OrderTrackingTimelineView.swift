// PATH: RSMS/Shared/Views/OrderTrackingTimelineView.swift

import SwiftUI

struct OrderTrackingTimelineView: View {
    let shipment: CustomerShippingViewModel.OrderShipment
    
    private let steps = [
        (status: "accepted", label: "Order Accepted", icon: "checkmark.circle"),
        (status: "picked_up", label: "Picked Up", icon: "shippingbox"),
        (status: "in_transit", label: "In Transit", icon: "truck.box"),
        (status: "out_for_delivery", label: "Out for Delivery", icon: "bicycle"),
        (status: "delivered", label: "Delivered", icon: "house.check")
    ]
    
    private var currentStepIndex: Int {
        steps.firstIndex(where: { $0.status == shipment.status }) ?? -1
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("TRACKING: \(shipment.awbNumber ?? "PENDING")")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.luxurySecondaryText)
                    Text(shipment.courierName ?? "Standard Courier")
                        .font(BrandFont.body(14, weight: .semibold))
                }
                Spacer()
                if let eta = shipment.estimatedDelivery {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("EST. DELIVERY")
                            .font(.system(size: 10, weight: .bold))
                        Text(eta.formatted(date: .abbreviated, time: .omitted))
                            .font(.system(size: 12, weight: .semibold))
                    }
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                ForEach(0..<steps.count, id: \.self) { index in
                    TimelineRow(step: steps[index], isCompleted: index <= currentStepIndex, isCurrent: index == currentStepIndex, isLast: index == steps.count - 1)
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: Color.black.opacity(0.03), radius: 10, y: 5)
    }
}

struct TimelineRow: View {
    let step: (status: String, label: String, icon: String)
    let isCompleted: Bool
    let isCurrent: Bool
    let isLast: Bool
    @State private var pulse = false
    var body: some View {
        HStack(alignment: .top, spacing: 15) {
            VStack(spacing: 0) {
                ZStack {
                    Circle().fill(isCompleted ? BoutiqueTheme.primary : Color.luxuryBackground).frame(width: 18, height: 18)
                    if isCurrent {
                        Circle().stroke(BoutiqueTheme.primary, lineWidth: 2).frame(width: 26, height: 26).scaleEffect(pulse ? 1.2 : 1.0).opacity(pulse ? 0 : 1).onAppear {
                            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) { pulse = true }
                        }
                    }
                    Image(systemName: isCompleted ? "checkmark" : step.icon).font(.system(size: 8, weight: .bold)).foregroundStyle(isCompleted ? Color.white : Color.luxurySecondaryText)
                }
                if !isLast { Rectangle().fill(isCompleted ? BoutiqueTheme.primary : Color.luxuryBackground).frame(width: 2, height: 40) }
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(step.label).font(.system(size: 14, weight: isCurrent ? .bold : .medium)).foregroundStyle(isCompleted ? Color.luxuryPrimaryText : Color.luxurySecondaryText)
                if isCurrent { Text("In Progress").font(.system(size: 11)).foregroundStyle(BoutiqueTheme.primary) }
            }
            .padding(.top, 2)
            Spacer()
        }
    }
}
