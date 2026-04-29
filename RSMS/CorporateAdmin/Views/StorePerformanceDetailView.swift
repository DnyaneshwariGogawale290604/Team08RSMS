import SwiftUI
import MapKit

struct StorePerformanceDetailView: View {
    let performance: StorePerformance
    @Environment(\.dismiss) private var dismiss
    
    @State private var storeCategoryData: [CategorySales] = []
    @State private var isLoadingData = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    // 1. Performance Summary Card
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Performance Summary")
                            .font(.system(size: 18, weight: .bold, design: .serif))
                            .foregroundColor(CatalogTheme.primaryText)
                        
                        VStack(spacing: 24) {
                            ActivityRingView(progress: performance.achievementPercentage)
                                .frame(width: 140, height: 140)
                            
                            HStack(spacing: 16) {
                                compactStatCard(
                                    title: "Total Sales",
                                    value: formatCurrency(performance.totalSales),
                                    icon: "indianrupeesign.circle.fill",
                                    color: CatalogTheme.primary
                                )
                                
                                compactStatCard(
                                    title: "Monthly Target",
                                    value: formatCurrency(performance.target),
                                    icon: "target",
                                    color: CatalogTheme.secondaryText
                                )
                            }
                        }
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)

                    // 2. Sales by Category Card
                    let currentData = isLoadingData ? getMockCategorySales(for: performance) : storeCategoryData
                    let totalSales = currentData.reduce(0) { $0 + $1.totalSales }
                    
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Sales by Category")
                                .font(.system(size: 18, weight: .bold, design: .serif))
                                .foregroundColor(CatalogTheme.primaryText)
                            Text("Revenue distribution for this store")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(CatalogTheme.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 24) {
                            CategoryPieChartView(data: currentData, total: totalSales)
                                .frame(width: 140, height: 140)
                                .overlay {
                                    if isLoadingData {
                                        ProgressView()
                                            .tint(CatalogTheme.primary)
                                    }
                                }
                            
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(Array(currentData.enumerated()), id: \.element.id) { index, item in
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(categoryColor(at: index))
                                            .frame(width: 8, height: 8)
                                        
                                        Text(item.category)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundColor(CatalogTheme.primaryText)
                                        
                                        Spacer()
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)

                    // 3. Location & Details Card
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Location & Details")
                            .font(.system(size: 18, weight: .bold, design: .serif))
                            .foregroundColor(CatalogTheme.primaryText)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            detailRow(icon: "calendar", label: "Opening Date", value: performance.store.openingDate ?? "N/A")
                            Divider()
                            detailRow(icon: "info.circle", label: "Status", value: (performance.store.status ?? "Active").capitalized)
                            Divider()
                            detailRow(icon: "house.fill", label: "Address", value: performance.store.address ?? performance.store.location)
                        }
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                    
                    Spacer(minLength: 20)
                }
                .padding(20)
            }
            .background(CatalogTheme.background.ignoresSafeArea())
            .navigationTitle(performance.store.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .foregroundColor(CatalogTheme.primary)
                }
            }
            .task {
                await fetchRealCategorySales()
            }
        }
    }

    private func fetchRealCategorySales() async {
        do {
            let realData = try await AdminService.shared.fetchCategoryWiseSales(for: performance.store.id)
            await MainActor.run {
                if !realData.isEmpty {
                    self.storeCategoryData = realData
                }
                self.isLoadingData = false
            }
        } catch {
            print("Error fetching category sales: \(error)")
            await MainActor.run {
                self.isLoadingData = false
            }
        }
    }

    private func compactStatCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(CatalogTheme.secondaryText)
            }
            
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(CatalogTheme.primaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(CatalogTheme.surface.opacity(0.5))
        .cornerRadius(12)
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(CatalogTheme.primary)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(CatalogTheme.secondaryText)
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(CatalogTheme.primaryText)
            }
        }
    }

    private func formatCurrency(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "₹"
        formatter.maximumFractionDigits = 0
        
        if value >= 10_000_000 {
            return String(format: "₹%.1f Cr", value / 10_000_000)
        } else if value >= 100_000 {
            return String(format: "₹%.1f L", value / 100_000)
        } else if value >= 1_000 {
            return String(format: "₹%.1f K", value / 1_000)
        } else {
            return formatter.string(from: NSNumber(value: value)) ?? "₹\(Int(value))"
        }
    }
    
    private func getMockCategorySales(for performance: StorePerformance) -> [CategorySales] {
        let categories = ["Sunglasses", "Watches", "Purses", "Belts", "Fragrances"]
        let baseSales = performance.totalSales / 5
        
        // Use store name hash to make data consistent but unique per store
        let hash = abs(performance.store.name.hashValue)
        
        return categories.enumerated().map { index, category in
            let variation = Double((hash + index) % 40) / 100.0 + 0.8 // 0.8 to 1.2 variation
            return CategorySales(
                category: category,
                totalSales: baseSales * variation
            )
        }
    }
    
    private func categoryColor(at index: Int) -> Color {
        let colors: [Color] = [
            Color(hex: "#6E5155"), // Theme Primary
            Color(hex: "#E67E22"), // Orange
            Color(hex: "#27AE60"), // Green
            Color(hex: "#2980B9"), // Blue
            Color(hex: "#8E44AD"), // Purple
            Color(hex: "#C0392B"), // Red
            Color(hex: "#F1C40F"), // Yellow
            Color(hex: "#16A085")  // Teal
        ]
        return colors[index % colors.count]
    }
}

