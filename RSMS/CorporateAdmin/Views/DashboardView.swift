import SwiftUI

public struct DashboardView: View {
    @StateObject private var viewModel = InventoryDashboardViewModel()
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Stock Summary Cards
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Stock Summary")
                                .font(.headline)
                                .foregroundColor(.appPrimaryText)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                                statCard(title: "Available", value: "\(viewModel.availableCount)", icon: "checkmark.circle.fill", color: .green)
                                statCard(title: "Reserved", value: "\(viewModel.reservedCount)", icon: "lock.fill", color: .orange)
                                statCard(title: "In Transit", value: "\(viewModel.inTransitCount)", icon: "box.truck.fill", color: .blue)
                                statCard(title: "Sold", value: "\(viewModel.soldCount)", icon: "cart.fill", color: .gray)
                            }
                            .padding(.horizontal)
                        }
                        .padding(.top, 16)
                        
                        // Recent Transfers
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Recent Transfers")
                                    .font(.headline)
                                    .foregroundColor(.appPrimaryText)
                                Spacer()
                                NavigationLink("View All", destination: TransfersTabView(selectedTab: .constant(1), prefilledSKUMagic: .constant(nil as String?)))
                                    .font(.subheadline)
                                    .foregroundColor(.appAccent)
                            }
                            .padding(.horizontal)
                            
                            if viewModel.recentActivity.isEmpty {
                                EmptyStateView(icon: "arrow.left.arrow.right", title: "No Transfers", message: "No active transfers running.")
                            } else {
                                ForEach(viewModel.recentActivity.prefix(3), id: \.id) { shipment in
                                    transferRow(for: shipment)
                                        .padding(.horizontal)
                                }
                            }
                        }
                        
                        // Exceptions Panel
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Exceptions")
                                .font(.headline)
                                .foregroundColor(.appPrimaryText)
                                .padding(.horizontal)
                            
                            ReusableCardView {
                                VStack(alignment: .leading, spacing: 12) {
                                    exceptionRow(icon: "exclamationmark.triangle.fill", color: .orange, text: "2 Items Missing Verification")
                                    Divider()
                                    exceptionRow(icon: "rectangle.on.rectangle", color: .red, text: "1 Duplicate RFID Scan detected")
                                    Divider()
                                    exceptionRow(icon: "location.slash.fill", color: .purple, text: "4 Items in wrong location")
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 20)
                }
                .refreshable { 
                    await viewModel.loadDashboardData()
                }
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await viewModel.loadDashboardData()
            }
        }
    }
    
    @ViewBuilder
    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .padding(10)
                    .background(color.opacity(0.15))
                    .cornerRadius(10)
                Spacer()
            }
            
            Text(value)
                .font(.title2.bold())
                .foregroundColor(.appPrimaryText)
                
            Text(title)
                .font(.subheadline)
                .foregroundColor(.appSecondaryText)
        }
        .padding(16)
        .appCardChrome()
    }

    @ViewBuilder
    private func transferRow(for shipment: Shipment) -> some View {
        ReusableCardView {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(shipment.request?.product?.name ?? "Order ID: \(shipment.id.uuidString.prefix(6))")
                        .font(.subheadline.bold())
                        .foregroundColor(.appPrimaryText)
                    Spacer()
                    Text(shipment.status.capitalized)
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.appAccent.opacity(0.16))
                        .foregroundColor(.appAccent)
                        .cornerRadius(6)
                }
                Text("To: Store")
                    .font(.caption)
                    .foregroundColor(.appSecondaryText)
            }
        }
    }
    
    @ViewBuilder
    private func exceptionRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.appPrimaryText)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.appBorder)
                .font(.caption)
        }
    }
}
