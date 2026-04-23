import SwiftUI

public struct StoreProductsTab: View {
    let storeId: UUID
    @StateObject private var viewModel: StoreProductViewModel
    
    @State private var showingAddModal = false
    @State private var productToRemove: StoreBaselineWithProduct?
    @State private var showingRemoveConfirmation = false
    
    public init(storeId: UUID) {
        self.storeId = storeId
        self._viewModel = StateObject(wrappedValue: StoreProductViewModel(storeId: storeId))
    }
    
    public var body: some View {
        ZStack {
            if viewModel.isLoading && viewModel.assignedProducts.isEmpty {
                LoadingView(message: "Loading products...")
                    .frame(maxHeight: .infinity)
            } else if viewModel.assignedProducts.isEmpty {
                VStack(spacing: 24) {
                    EmptyStateView(
                        icon: "shippingbox",
                        title: "No products assigned to this store yet",
                        message: "Add products from the global catalog to manage inventory baselines here."
                    )
                    
                    Button(action: { showingAddModal = true }) {
                        Text("+ Add Products to Store")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.black)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 32)
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        Button(action: { showingAddModal = true }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Add Products")
                            }
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Color.black)
                            .clipShape(Capsule())
                        }
                        
                        LazyVStack(spacing: 16) {
                            ForEach($viewModel.assignedProducts) { $item in
                                StoreAssignedProductCard(
                                    item: $item,
                                    onSave: { newQty in
                                        Task { await viewModel.updateQuantity(baselineId: item.id, newQuantity: newQty) }
                                    },
                                    onRemove: {
                                        productToRemove = item
                                        showingRemoveConfirmation = true
                                    }
                                )
                            }
                        }
                    }
                    .padding(16)
                }
                .refreshable { await viewModel.loadData() }
            }
        }
        .background(Color.brandOffWhite.ignoresSafeArea())
        .task {
            await viewModel.loadData()
        }

        .sheet(isPresented: $showingAddModal) {
            AddStoreProductModal(viewModel: viewModel)
        }
        .alert("Remove Product?", isPresented: $showingRemoveConfirmation, presenting: productToRemove) { item in
            Button("Cancel", role: .cancel) { }
            Button("Remove", role: .destructive) {
                Task { await viewModel.removeProduct(baselineId: item.id) }
            }
        } message: { item in
            Text("Are you sure you want to remove \(item.product.name) from this store? This will not delete the product from the global catalog.")
        }
    }
}

struct StoreAssignedProductCard: View {
    @Binding var item: StoreBaselineWithProduct
    let onSave: (Int) -> Void
    let onRemove: () -> Void
    
    @State private var editingQuantity: String = ""
    @State private var isEditing = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.product.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                    Text(item.product.category)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                Spacer()
                
                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.7))
                        .padding(8)
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            
            Divider().background(Color.gray.opacity(0.1))
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("BASELINE QUANTITY")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                    
                    if isEditing {
                        TextField("Qty", text: $editingQuantity)
                            .keyboardType(.numberPad)
                            .font(.system(size: 16, weight: .medium))
                            .padding(8)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                            .frame(width: 80)
                    } else {
                        Text("\(item.baseline.baselineQuantity)")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    if isEditing {
                        if let newQty = Int(editingQuantity) {
                            onSave(newQty)
                        }
                    } else {
                        editingQuantity = "\(item.baseline.baselineQuantity)"
                    }
                    isEditing.toggle()
                }) {
                    Text(isEditing ? "Save" : "Edit")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(isEditing ? Color.green : Color.black)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black.opacity(0.05), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
    }
}

