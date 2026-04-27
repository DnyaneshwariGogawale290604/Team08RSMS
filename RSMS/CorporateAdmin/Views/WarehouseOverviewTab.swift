import SwiftUI

struct WarehouseOverviewTab: View {
    let warehouse: Warehouse
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // Warehouse Info Card
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Image(systemName: "building.2.fill")
                            .foregroundColor(CatalogTheme.primary)
                        Text("Warehouse Details")
                            .font(.system(size: 16, weight: .bold, design: .serif))
                            .foregroundColor(CatalogTheme.primaryText)
                    }
                    
                    VStack(spacing: 0) {
                        infoRow(label: "Location", value: warehouse.location)
                        detailDivider
                        infoRow(label: "Address", value: warehouse.address ?? "Not set")
                        detailDivider
                        infoRow(label: "Status", value: warehouse.status?.capitalized ?? "Active")
                    }
                    .padding(16)
                    .background(Color.white)
                    .cornerRadius(AppTheme.cardCornerRadius)
                    .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                }
                .padding(.horizontal, 20)
                
                // Analytics Placeholder
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Image(systemName: "chart.pie.fill")
                            .foregroundColor(CatalogTheme.primary)
                        Text("Inventory Insights")
                            .font(.system(size: 16, weight: .bold, design: .serif))
                            .foregroundColor(CatalogTheme.primaryText)
                    }
                    
                    VStack(alignment: .center, spacing: 12) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 32))
                            .foregroundColor(CatalogTheme.surface)
                        
                        Text("Detailed analytics for this warehouse will appear here in a future update.")
                            .font(.system(size: 14))
                            .foregroundColor(CatalogTheme.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(Color.white)
                    .cornerRadius(AppTheme.cardCornerRadius)
                    .shadow(color: Color.black.opacity(0.04), radius: 12, x: 0, y: 4)
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 24)
        }
        .background(Color.clear)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(CatalogTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .multilineTextAlignment(.trailing)
                .foregroundColor(CatalogTheme.primaryText)
        }
        .padding(.vertical, 12)
    }

    private var detailDivider: some View {
        Divider()
            .background(CatalogTheme.divider)
    }
}
