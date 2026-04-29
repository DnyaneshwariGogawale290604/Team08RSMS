import SwiftUI

struct AllStoresPerformanceView: View {
    let stores: [StorePerformance]
    
    var body: some View {
        ZStack {
            CatalogTheme.background.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Array(stores.enumerated()), id: \.element.id) { index, performance in
                        Button(action: {
                            selectedStore = performance
                        }) {
                            StorePerformanceRow(performance: performance, rank: index + 1)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
        }
        .navigationTitle("All Stores Performance")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedStore) { performance in
            StorePerformanceDetailView(performance: performance)
        }
    }
    
    @State private var selectedStore: StorePerformance? = nil
}

struct StorePerformanceRow: View {
    let performance: StorePerformance
    let rank: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                // Rank Number
                ZStack {
                    Circle()
                        .fill(rank <= 3 ? CatalogTheme.primary : CatalogTheme.surface)
                        .frame(width: 28, height: 28)
                    Text("\(rank)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(rank <= 3 ? .white : CatalogTheme.primaryText)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(performance.store.name)
                        .font(.headline)
                        .foregroundColor(CatalogTheme.primaryText)
                    Text(performance.store.location)
                        .font(.caption)
                        .foregroundColor(CatalogTheme.secondaryText)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatCurrency(performance.totalSales))
                        .font(.headline)
                        .foregroundColor(CatalogTheme.primary)
                    Text("of \(formatCurrency(performance.target))")
                        .font(.caption2)
                        .foregroundColor(CatalogTheme.secondaryText)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
    
    private func formatCurrency(_ value: Double) -> String {
        if value >= 10_000_000 {
            return String(format: "₹%.1f Cr", value / 10_000_000)
        } else if value >= 100_000 {
            return String(format: "₹%.1f L", value / 100_000)
        } else if value >= 1_000 {
            return String(format: "₹%.1f K", value / 1_000)
        } else {
            return String(format: "₹%.0f", value)
        }
    }
}

