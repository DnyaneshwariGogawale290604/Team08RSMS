import SwiftUI

public struct AddStoreProductModal: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: StoreProductViewModel
    
    @State private var searchText = ""
    @State private var items: [SelectionItem] = []
    @State private var bulkQuantity: String = "10"
    @State private var showingError = false
    
    struct SelectionItem: Identifiable {
        let product: Product
        var isSelected: Bool
        var quantity: String
        var id: UUID { product.id }
    }
    
    public var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Bulk Actions & Search Header
                VStack(spacing: 16) {
                    TextField("Search globally...", text: $searchText)
                        .padding(10)
                        .background(Color.white)
                        .cornerRadius(AppTheme.cardCornerRadius)
                    
                    HStack {
                        Button(action: {
                            let allSelected = items.allSatisfy { $0.isSelected }
                            for i in items.indices {
                                items[i].isSelected = !allSelected
                            }
                        }) {
                            Text(items.allSatisfy({ $0.isSelected }) && !items.isEmpty ? "Deselect All" : "Select All")
                                .font(.subheadline)
                                .foregroundColor(.appAccent)
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Text("Set Bulk Qty:")
                                .font(.caption)
                                .foregroundColor(CatalogTheme.secondaryText)
                            TextField("10", text: $bulkQuantity)
                                .keyboardType(.numberPad)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(width: 60)
                            Button("Apply") {
                                for i in items.indices where items[i].isSelected {
                                    items[i].quantity = bulkQuantity
                                }
                            }
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .appPrimaryButtonChrome()
                        }
                    }
                }
                .padding()
                .background(Color.appBackground)
                
                Divider()
                
                List {
                    ForEach($items) { $item in
                        if searchText.isEmpty || item.product.name.localizedCaseInsensitiveContains(searchText) {
                            HStack(spacing: 16) {
                                Toggle("", isOn: $item.isSelected)
                                    .labelsHidden()
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.product.name)
                                        .font(.body)
                                    Text(item.product.category)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 4) {
                                    Text("Baseline")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                    TextField("Qty", text: $item.quantity)
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .frame(width: 60)
                                        .disabled(!item.isSelected)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationTitle("Add Core Products")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .tint(.appAccent)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    let selected = items.filter { $0.isSelected }
                    Button {
                        Task {
                            let results = selected.compactMap { item -> (Product, Int)? in
                                guard let qty = Int(item.quantity) else { return nil }
                                return (item.product, qty)
                            }
                            let success = await viewModel.addSelectedProducts(results)
                            if success {
                                dismiss()
                            } else {
                                showingError = true
                            }
                        }
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .disabled(selected.isEmpty)
                    .tint(.appAccent)
                }
            }
            .alert("Assignment Failed", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred while saving to Supabase.")
            }
            .onAppear {
                populateItems()
            }
            .onChange(of: viewModel.availableGlobalProducts) { _ in
                populateItems()
            }
            .onChange(of: viewModel.assignedProducts) { _ in
                populateItems()
            }
        }
    }
    
    private func populateItems() {
        let assignedIDs = Set(viewModel.assignedProducts.map { $0.productId })
        let unassigned = viewModel.availableGlobalProducts.filter { !assignedIDs.contains($0.id) }
        
        // Only add items that are not already in `self.items` to avoid resetting user selections
        let existingIds = Set(items.map { $0.id })
        let newItems = unassigned.filter { !existingIds.contains($0.id) }.map {
            SelectionItem(product: $0, isSelected: false, quantity: bulkQuantity)
        }
        
        self.items.append(contentsOf: newItems)
    }
}

private extension StoreBaselineWithProduct {
    var productId: UUID {
        product.id
    }
}
