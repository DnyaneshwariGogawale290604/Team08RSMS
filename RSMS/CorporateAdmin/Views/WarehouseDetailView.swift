import SwiftUI

public struct WarehouseDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var viewModel: WarehouseViewModel
    private let warehouseId: UUID

    @State private var warehouseDetails: Warehouse
    @State private var inventoryManager: InventoryManagerRecord?
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
            // headerView removed
            
            if isLoadingDetails {
                LoadingView(message: "Loading Warehouse Details...")
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 32) {

                        // Basic Details Card
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Warehouse Details")
                                .font(.system(size: 18, weight: .bold, design: .serif))
                                .foregroundColor(CatalogTheme.deepAccent)
                            
                            VStack(spacing: 0) {
                                detailRow(label: "Location", value: warehouseDetails.location)
                                divider
                                detailRow(label: "Status", value: warehouseDetails.status?.capitalized ?? "Active")
                            }
                            .padding(16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
                        }
                        .padding(.horizontal, 24)

                        // Inventory Manager Section
                        VStack(alignment: .leading, spacing: 20) {
                            Text("Inventory Manager")
                                .font(.system(size: 18, weight: .bold, design: .serif))
                                .foregroundColor(CatalogTheme.deepAccent)
                            
                            if let manager = inventoryManager {
                                VStack(spacing: 0) {
                                    detailRow(label: "Name", value: manager.user?.displayName ?? "Unknown")
                                    divider
                                    detailRow(label: "Employee ID", value: manager.user?.id.uuidString.prefix(8).uppercased() ?? "N/A")
                                    divider
                                    detailRow(label: "Email", value: manager.user?.email ?? "N/A")
                                    divider
                                    detailRow(label: "Phone", value: manager.user?.phone ?? "N/A")
                                }
                                .padding(16)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
                            } else {
                                Text("No inventory manager assigned to this warehouse.")
                                    .font(.system(size: 14, design: .serif))
                                    .foregroundColor(CatalogTheme.secondaryText)
                                    .padding(20)
                                    .frame(maxWidth: .infinity)
                                    .background(Color.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.vertical, 24)
                }
                
                archiveButton
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
            }
        }
        .background(CatalogTheme.background.ignoresSafeArea())
        .navigationTitle(warehouseDetails.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
                .foregroundColor(CatalogTheme.primaryText)
            }
        }
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
                    Text("Edit")
                        .font(.system(size: 14, weight: .bold, design: .serif))
                        .foregroundColor(CatalogTheme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white)
                        .clipShape(Capsule())
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 2)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(label)
                .font(.system(size: 14, design: .serif))
                .foregroundColor(CatalogTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .serif))
                .multilineTextAlignment(.trailing)
                .foregroundColor(CatalogTheme.primaryText)
        }
        .padding(.vertical, 12)
    }

    private var divider: some View {
        Divider()
            .background(CatalogTheme.divider)
    }

    private func loadWarehouseDetails() async {
        isLoadingDetails = true
        defer { isLoadingDetails = false }

        do {
            let service = WarehouseService.shared
            warehouseDetails = try await service.fetchWarehouse(id: warehouseId)
            let managers = try await service.fetchInventoryManagers(forWarehouse: warehouseId)
            inventoryManager = managers.first
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

