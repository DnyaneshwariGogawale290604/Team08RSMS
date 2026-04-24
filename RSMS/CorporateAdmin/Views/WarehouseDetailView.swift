import SwiftUI

public struct WarehouseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var viewModel: WarehouseViewModel
    private let warehouseId: UUID

    @State private var selectedTab: Int = 0
    @State private var warehouseDetails: Warehouse
    @State private var isLoadingDetails = false
    @State private var localErrorMessage: String?
    @State private var showingEditSheet = false
    @State private var showingArchiveConfirmation = false

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
                
                archiveButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
            }
        }
        .background(CatalogTheme.background.ignoresSafeArea())
        .navigationBarHidden(true)
        .navigationBarBackButtonHidden(true)
        .navigationTitle("")
        .task {
            await loadWarehouseDetails()
        }
        .sheet(isPresented: $showingEditSheet) {
            WarehouseFormView(viewModel: viewModel, editingWarehouse: warehouseDetails)
        }
        .alert(isArchived ? "Unarchive Warehouse" : "Archive Warehouse", isPresented: $showingArchiveConfirmation) {
            Button("Cancel", role: .cancel) { }
            if isArchived {
                Button("Unarchive") {
                    Task { await toggleArchiveStatus() }
                }
            } else {
                Button("Archive", role: .destructive) {
                    Task { await toggleArchiveStatus() }
                }
            }
        } message: {
            Text(isArchived 
                 ? "Are you sure you want to unarchive this warehouse? It will be marked as active again."
                 : "Are you sure you want to archive this warehouse? It will be marked as inactive.")
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
        HStack(spacing: 12) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(CatalogTheme.primary)
                    .frame(width: 44, height: 44)
                    .background(Color.white)
                    .clipShape(Circle())
                    .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
            }
            
            Spacer()
            
            Text(warehouseDetails.displayLabel)
                .font(.system(size: 18, weight: .bold, design: .serif))
                .foregroundColor(CatalogTheme.primaryText)
            
            Spacer()
            
            HStack(spacing: 8) {
                Button(action: { showingEditSheet = true }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(CatalogTheme.primary)
                        .frame(width: 40, height: 40)
                        .background(Color.white)
                        .clipShape(Circle())
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                }
            }
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
                        .foregroundColor(selectedTab == index ? .white : CatalogTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedTab == index ? CatalogTheme.primary : Color.clear
                        )
                        .clipShape(Capsule())
                }
            }
        }
        .padding(4)
        .background(CatalogTheme.surface.opacity(0.5))
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

    private var isArchived: Bool {
        (warehouseDetails.status ?? "active").lowercased() == "inactive"
    }

    private func toggleArchiveStatus() async {
        do {
            let newStatus = isArchived ? "active" : "inactive"
            try await WarehouseService.shared.updateWarehouseStatus(id: warehouseId, status: newStatus)
            await loadWarehouseDetails() // Refresh local state
            showingArchiveConfirmation = false
        } catch {
            localErrorMessage = "Failed to update warehouse status: \(error.localizedDescription)"
        }
    }

    private var archiveButton: some View {
        let isArchived = (warehouseDetails.status ?? "active").lowercased() == "inactive"
        return Button(action: { showingArchiveConfirmation = true }) {
            HStack {
                Image(systemName: isArchived ? "arrow.uturn.backward.circle.fill" : "archivebox.fill")
                Text(isArchived ? "Unarchive Warehouse" : "Archive Warehouse")
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(isArchived ? CatalogTheme.primary : CatalogTheme.deepAccent)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: CatalogTheme.deepAccent.opacity(0.2), radius: 8, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

