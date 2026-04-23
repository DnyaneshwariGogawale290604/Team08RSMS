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
    
    public init(viewModel: WarehouseViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color.brandOffWhite.ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        headerView
                        
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Warehouse Information")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.appSecondaryText)
                            
                            whiteCard {
                                inlineTextField("Warehouse Name", text: $name)
                                divider
                                inlineTextField("Location (e.g. City)", text: $location)
                                divider
                                HStack {
                                    Text("Status")
                                        .font(.system(size: 16))
                                        .foregroundColor(.black)
                                    VStack(alignment: .trailing, spacing: 8) {
                                        HStack(spacing: 8) {
                                            let isActive = self.isActive
                                            Text(isActive ? "Active" : "Inactive")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(isActive ? .green : .red)
                                            
                                            Toggle("", isOn: $isActive)
                                                .labelsHidden()
                                                .toggleStyle(SwitchToggleStyle(tint: .green))
                                                .scaleEffect(0.8)
                                        }
                                    }
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Address")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.appSecondaryText)
                            
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
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unknown Error")
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Button("Cancel") { dismiss() }
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white)
                .clipShape(Capsule())
            
            Spacer()
            
            Text("Add Warehouse")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.black)
            
            Spacer()
            
            Button("Save") {
                Task { await saveWarehouse() }
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(canSave ? .black : .gray.opacity(0.4))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white)
            .clipShape(Capsule())
            .disabled(!canSave)
        }
        .padding(.top, 10)
    }
    
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
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
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
        
        let newWarehouse = Warehouse(
            id: UUID(),
            name: name,
            location: location,
            address: address.isEmpty ? nil : address,
            status: isActive ? "active" : "inactive"
        )
        
        do {
            try await WarehouseService.shared.createWarehouse(newWarehouse)
            await viewModel.fetchWarehouses()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            showingErrorAlert = true
        }
    }
}
