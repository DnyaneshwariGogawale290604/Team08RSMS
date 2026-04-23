import SwiftUI

struct WarehouseOverviewTab: View {
    let warehouse: Warehouse
    
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                // Warehouse Info Card
                VStack(alignment: .leading, spacing: 16) {
                    Text("Warehouse Details")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Divider().background(Color.gray.opacity(0.1))
                    
                    InfoRow(label: "Location", value: warehouse.location)
                    InfoRow(label: "Address", value: warehouse.address ?? "Not set")
                    InfoRow(label: "Status", value: warehouse.status?.capitalized ?? "Active")
                }
                .padding(20)
                .background(Color.white)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 16)
                
                // Analytics Placeholder or additional info
                VStack(alignment: .leading, spacing: 16) {
                    Text("Inventory Stats")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text("Detailed analytics for this warehouse will appear here in a future update.")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.black.opacity(0.05), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 20)
        }
        .background(Color.brandOffWhite.ignoresSafeArea())
    }
}

private struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .font(.system(size: 15))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(.black)
                .multilineTextAlignment(.trailing)
        }
    }
}
