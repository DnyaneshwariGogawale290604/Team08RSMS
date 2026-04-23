import SwiftUI

public struct StoreStaffTab: View {
    let storeId: UUID
    @StateObject private var viewModel: StoreStaffViewModel
    
    public init(storeId: UUID) {
        self.storeId = storeId
        self._viewModel = StateObject(wrappedValue: StoreStaffViewModel(storeId: storeId))
    }
    
    public var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.boutiqueManagers.isEmpty && viewModel.salesAssociates.isEmpty {
                LoadingView(message: "Loading Staff...")
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Section 1: Boutique Manager
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Boutique Manager")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                            
                            if viewModel.boutiqueManagers.isEmpty {
                                EmptyStaffCard(
                                    title: "No boutique manager assigned",
                                    subtitle: "The assigned boutique manager for this store will appear here."
                                )
                            } else {
                                ForEach(viewModel.boutiqueManagers) { manager in
                                    if let user = manager.user {
                                        StaffCardView(user: user, role: "Assigned", isManager: true)
                                    }
                                }
                            }
                        }
                        
                        // Section 2: Sales Associates
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Sales Associates")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.horizontal, 16)
                            
                            if viewModel.salesAssociates.isEmpty {
                                EmptyStaffCard(
                                    title: "No sales associates found",
                                    subtitle: "Sales associates assigned to this store will appear below the boutique manager."
                                )
                            } else {
                                ForEach(viewModel.salesAssociates) { associate in
                                    if let user = associate.user {
                                        StaffCardView(user: user, role: "Sales Associate", isManager: false)
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
        .background(Color.brandOffWhite.ignoresSafeArea())
        .task {
            await viewModel.fetchStaff()
        }
    }

}

struct EmptyStaffCard: View {
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
        .background(Color.black.opacity(0.04))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
}

private struct StaffCardView: View {
    let user: User
    let role: String
    let isManager: Bool
    
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
                
                Text(isManager ? "New York" : "Reports to boutique manager")
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


