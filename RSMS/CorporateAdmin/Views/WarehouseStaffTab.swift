import SwiftUI

struct WarehouseStaffTab: View {
    let warehouseId: UUID
    @StateObject private var viewModel: WarehouseStaffViewModel
    
    init(warehouseId: UUID) {
        self.warehouseId = warehouseId
        self._viewModel = StateObject(wrappedValue: WarehouseStaffViewModel(warehouseId: warehouseId))
    }
    
    var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.inventoryManagers.isEmpty {
                LoadingView(message: "Loading Staff...")
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Inventory Managers")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                            
                            if viewModel.inventoryManagers.isEmpty {
                                WarehouseEmptyStaffCard(
                                    title: "No inventory managers assigned",
                                    subtitle: "The assigned inventory manager for this warehouse will appear here."
                                )
                            } else {
                                ForEach(viewModel.inventoryManagers) { manager in
                                    if let user = manager.user {
                                        WarehouseStaffCardView(user: user, role: "Assigned")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 20)
                }
                .refreshable {
                    await viewModel.fetchStaff()
                }
            }
        }
        .background(Color.clear)
        .task {
            await viewModel.fetchStaff()
        }
    }
}

private struct WarehouseEmptyStaffCard: View {
    let title: String
    let subtitle: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.black.opacity(0.8))
            
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundColor(.gray)
        }
        .padding(24)
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
}

private struct WarehouseStaffCardView: View {
    let user: User
    let role: String
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(user.name ?? "Unknown")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    Text(role)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.05))
                        .clipShape(Capsule())
                }
                
                Text("Manager for this warehouse")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                
                if let email = user.email {
                    HStack(spacing: 6) {
                        Image(systemName: "envelope")
                            .font(.system(size: 13))
                        Text(email)
                            .font(.system(size: 14))
                    }
                    .foregroundColor(.gray.opacity(0.7))
                    .padding(.top, 4)
                }
            }
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
    }
}
