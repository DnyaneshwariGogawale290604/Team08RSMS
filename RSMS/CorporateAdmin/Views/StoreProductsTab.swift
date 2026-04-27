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
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
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
        .overlay(alignment: .bottomTrailing) {
            if !viewModel.isLoading {
                Button(action: { showingAddModal = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(CatalogTheme.deepAccent)
                        .clipShape(Circle())
                        .shadow(color: CatalogTheme.deepAccent.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
        }
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
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundColor(CatalogTheme.primaryText)
                    Text(item.product.category)
                        .font(.system(size: 13, design: .serif))
                        .foregroundColor(CatalogTheme.secondaryText)
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
                            .font(.system(size: 16, weight: .medium, design: .serif))
                            .padding(8)
                            .background(CatalogTheme.surface)
                            .cornerRadius(8)
                            .frame(width: 80)
                    } else {
                        Text("\(item.baseline.baselineQuantity)")
                            .font(.system(size: 18, weight: .bold, design: .serif))
                            .foregroundColor(CatalogTheme.primaryText)
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
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundColor(isEditing ? .green : CatalogTheme.primary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(CatalogTheme.surface)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 5)
    }
}

