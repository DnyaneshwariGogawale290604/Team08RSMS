import SwiftUI

public struct WarehouseFormView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: WarehouseViewModel
    
    @State private var name: String = ""
    @State private var location: String = ""
    @State private var address: String = ""
    @State private var isActive: Bool = true
    
    @State private var errorMessage: String?
    @State private var showingErrorAlert = false
    @State private var isSaving = false
    
    private let editingWarehouse: Warehouse?

    public init(viewModel: WarehouseViewModel, editingWarehouse: Warehouse? = nil) {
        self.viewModel = viewModel
        self.editingWarehouse = editingWarehouse
        
        if let warehouse = editingWarehouse {
            _name = State(initialValue: warehouse.name)
            _location = State(initialValue: warehouse.location)
            _address = State(initialValue: warehouse.address ?? "")
            _isActive = State(initialValue: warehouse.status == "active")
        }
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                CatalogTheme.background.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 28) {
                            VStack(alignment: .leading, spacing: 14) {
                            Text("Warehouse Information")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(CatalogTheme.deepAccent)
                            
                            whiteCard {
                                inlineTextField("Warehouse Name", text: $name)
                                divider
                                inlineTextField("Location (e.g. City)", text: $location)
                                divider
                                Toggle(isOn: $isActive) {
                                    HStack {
                                        Text("Status")
                                            .font(.system(size: 16))
                                            .foregroundColor(.black)
                                        Spacer()
                                        Text(isActive ? "Active" : "Inactive")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                            .padding(.trailing, 8)
                                    }
                                }
                                .toggleStyle(SwitchToggleStyle(tint: CatalogTheme.primary))
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Address")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(CatalogTheme.deepAccent)
                            
                            whiteCard {
                                TextField("Street, landmark, city, postal code", text: $address, axis: .vertical)
                                    .lineLimit(3...5)
                                    .font(.system(size: 16))
                                    .foregroundColor(.black)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                }
            }
            .navigationTitle(editingWarehouse == nil ? "Add Warehouse" : "Edit Warehouse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(CatalogTheme.primaryText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task { await saveWarehouse() }
                    }
                    .foregroundColor(canSave ? CatalogTheme.primaryText : Color.gray)
                    .disabled(!canSave)
                }
            }
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unknown Error")
            }
        }
    }
    
    // Removed headerView
    
    @ViewBuilder
    private func whiteCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(CatalogTheme.divider, lineWidth: 0.8)
        )
    }
    
    private func inlineTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .font(.system(size: 16))
            .foregroundColor(.black)
    }
    
    private var divider: some View {
        Divider().background(Color.gray.opacity(0.1))
    }
    
    private var canSave: Bool {
        !isSaving && !name.isEmpty && !location.isEmpty
    }
    
    private func saveWarehouse() async {
        isSaving = true
        defer { isSaving = false }
        
        let finalWarehouse = Warehouse(
            id: editingWarehouse?.id ?? UUID(),
            name: name,
            location: location,
            address: address.isEmpty ? nil : address,
            status: isActive ? "active" : "inactive"
        )
        
        do {
            if let _ = editingWarehouse {
                try await WarehouseService.shared.updateWarehouse(finalWarehouse)
            } else {
                try await WarehouseService.shared.createWarehouse(finalWarehouse)
            }
            await viewModel.fetchWarehouses()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
}
