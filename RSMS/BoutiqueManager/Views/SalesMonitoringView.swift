import SwiftUI

// SalesMonitoringView is kept for reference but is no longer shown in a tab.
// The Sales tab has been replaced by the Catalog tab.
public struct SalesMonitoringView: View {
    @EnvironmentObject var salesVM: BoutiqueSalesViewModel

    public var body: some View {
        NavigationView {
            ZStack {
                Theme.offWhite.ignoresSafeArea()

                if salesVM.isLoading {
                    ProgressView()
                } else if let error = salesVM.errorMessage {
                    Text(error).foregroundColor(Theme.error)
                } else {
                    VStack {
                        // Total Revenue Header
                        VStack(spacing: 8) {
                            Text("Total Revenue")
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                                .tracking(1)

                            Text(String(format: "₹%.2f", salesVM.totalRevenue))
                                .font(.system(size: 36, weight: .light))
                                .foregroundColor(Theme.textPrimary)
                        }
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                        .background(Theme.beige)

                        Divider().background(Theme.border)

                        List {
                            ForEach(salesVM.salesList) { order in
                                SalesOrderRow(order: order)
                                    .listRowInsets(EdgeInsets())
                                    .listRowBackground(Color.clear)
                                    .listRowSeparator(.hidden)
                                    .padding(.vertical, 8)
                            }
                        }
                        .listStyle(.plain)
                        .padding(.horizontal)
                    }
                }
            }
            .navigationTitle("Sales")
            .onAppear {
                salesVM.fetchSales()
            }
        }
    }
}

struct SalesOrderRow: View {
    let order: SalesOrder

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(order.createdAt, style: .date)
                    .font(.body)
                    .foregroundColor(Theme.textPrimary)

                Text(order.status ?? "Completed")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()

            Text(String(format: "+₹%.2f", order.totalAmount))
                .font(.headline)
                .foregroundColor(Theme.success)
        }
        .luxuryCardStyle()
    }
}
