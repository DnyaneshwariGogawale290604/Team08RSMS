import SwiftUI

public struct FulfillmentView: View {
    @ObservedObject private var engine = InventoryEngine.shared
    @State private var selectedDemand: Transfer? = nil
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            
                            Text("Pending Demands")
                                .font(.title3.bold())
                                .foregroundColor(.appPrimaryText)
                                .padding(.horizontal)
                                .padding(.top, 16)
                            
                            if engine.demands.isEmpty {
                                EmptyStateView(icon: "checkmark.seal", title: "No Pending Demands", message: "All requests have been fulfilled.")
                                    .padding(.horizontal)
                            } else {
                                ForEach(engine.demands) { demand in
                                    demandCard(demand)
                                        .padding(.horizontal)
                                        .onTapGesture {
                                            withAnimation {
                                                selectedDemand = selectedDemand?.id == demand.id ? nil : demand
                                            }
                                        }
                                        
                                    if selectedDemand?.id == demand.id {
                                        validationPanel(for: demand)
                                            .padding(.horizontal)
                                            .transition(.opacity.combined(with: .move(edge: .top)))
                                    }
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Fulfillment")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    @ViewBuilder
    private func demandCard(_ demand: Transfer) -> some View {
        ReusableCardView {
            VStack(alignment: .leading, spacing: AppTheme.compactSpacing) {
                HStack(alignment: .top) {
                    Text(demand.orderId)
                        .font(.headline)
                        .foregroundColor(.appPrimaryText)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 10) {
                        Text(demand.status.rawValue)
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(20)
                        AppCardChevron()
                    }
                }
                
                HStack(spacing: 4) {
                    Image(systemName: "building.2")
                        .foregroundColor(.appSecondaryText)
                        .font(.caption)
                    Text("Requesting: \(demand.toLocation)")
                        .font(.subheadline)
                        .foregroundColor(.appSecondaryText)
                }
                
                let qty = demand.items.map { $0.quantity }.reduce(0, +)
                Text("\(qty) Items Requested")
                    .font(.footnote)
                    .foregroundColor(.appSecondaryText)
            }
        }
        .shadow(color: selectedDemand?.id == demand.id ? Color.appAccent.opacity(0.22) : .clear, radius: 10, x: 0, y: 4)
    }
    
    @ViewBuilder
    private func validationPanel(for demand: Transfer) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stock Validation")
                .font(.headline)
                .foregroundColor(.appPrimaryText)
                
            ForEach(demand.items) { item in
                let available = engine.inventory.filter { $0.productName == item.productName && $0.status == .available }.count
                let isSufficient = available >= item.quantity
                
                HStack {
                    Text(item.productName)
                        .font(.subheadline)
                        .foregroundColor(.appPrimaryText)
                    Spacer()
                    Text("\(available) / \(item.quantity) Available")
                        .font(.subheadline.bold())
                        .foregroundColor(isSufficient ? .green : .red)
                }
                
                if !isSufficient {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("Insufficient stock. Cannot fully fulfill order.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }
            
            let canFulfill = demand.items.allSatisfy { item in
                engine.inventory.filter { $0.productName == item.productName && $0.status == .available }.count >= item.quantity
            }
            
            Button(action: {
                if canFulfill {
                    Task { await engine.dispatch(demand: demand) }
                    selectedDemand = nil
                }
            }) {
                HStack {
                    if engine.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text(canFulfill ? "Create Shipment & Dispatch" : "Cannot Fulfill")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canFulfill ? Color.appAccent : Color.appAccent.opacity(0.45))
                .foregroundColor(.white)
                .cornerRadius(AppTheme.buttonCornerRadius)
            }
            .disabled(!canFulfill || engine.isLoading)
        }
        .padding()
        .background(Color.appAccent.opacity(0.08))
        .cornerRadius(AppTheme.cardCornerRadius)
    }
}
