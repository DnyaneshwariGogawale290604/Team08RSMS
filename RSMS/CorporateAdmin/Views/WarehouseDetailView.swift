import SwiftUI

public struct WarehouseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var viewModel: WarehouseViewModel
    private let warehouseId: UUID

    @State private var selectedTab: Int = 0
    @State private var warehouseDetails: Warehouse
    @State private var isLoadingDetails = false
    @State private var localErrorMessage: String?

    public init(viewModel: WarehouseViewModel, warehouse: Warehouse) {
        self.viewModel = viewModel
        self.warehouseId = warehouse.id
        self._warehouseDetails = State(initialValue: warehouse)
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerView
            
            pickerView
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 16)

            if isLoadingDetails && selectedTab == 0 {
                LoadingView(message: "Loading Warehouse Details...")
                    .frame(maxHeight: .infinity)
            } else {
                tabContent
                    .frame(maxHeight: .infinity)
            }
        }
        .background(Color.brandOffWhite.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .task {
            await loadWarehouseDetails()
        }
        .alert(
            "Warehouse Error",
            isPresented: Binding(
                get: { localErrorMessage != nil },
                set: { if !$0 { localErrorMessage = nil } }
            )
        ) {
            Button("OK", role: .cancel) {
                localErrorMessage = nil
            }
        } message: {
            Text(localErrorMessage ?? "Unable to load warehouse details.")
        }
    }

    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .frame(width: 44, height: 44)
                    .background(Color.white)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.black.opacity(0.05), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.03), radius: 5, x: 0, y: 2)
            }
            
            Spacer()
            
            Text(warehouseDetails.displayLabel)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.black)
            
            Spacer()
            
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var pickerView: some View {
        HStack(spacing: 4) {
            let titles = ["Overview", "Staff"]
            ForEach(0..<titles.count, id: \.self) { index in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                }) {
                    Text(titles[index])
                        .font(.system(size: 14, weight: selectedTab == index ? .semibold : .medium))
                        .foregroundColor(selectedTab == index ? .black : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            selectedTab == index ? Color.white : Color.clear
                        )
                        .clipShape(Capsule())
                        .overlay(
                            Capsule().stroke(selectedTab == index ? Color.black.opacity(0.03) : Color.clear, lineWidth: 1)
                        )
                }
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.06))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var tabContent: some View {
        if selectedTab == 0 {
            WarehouseOverviewTab(warehouse: warehouseDetails)
        } else {
            WarehouseStaffTab(warehouseId: warehouseId)
        }
    }

    private func loadWarehouseDetails() async {
        isLoadingDetails = true
        defer { isLoadingDetails = false }

        do {
            let service = WarehouseService.shared
            warehouseDetails = try await service.fetchWarehouse(id: warehouseId)
            localErrorMessage = nil
        } catch {
            localErrorMessage = error.localizedDescription
        }
    }
}
