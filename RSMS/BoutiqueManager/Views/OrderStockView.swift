import SwiftUI

public struct OrderStockView: View {
    @EnvironmentObject var inventoryVM: InventoryViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State public var selectedInventoryId: UUID?
    @State private var quantityToOrderStr = ""
    
    public init(preselectedInventoryId: UUID? = nil) {
        _selectedInventoryId = State(initialValue: preselectedInventoryId)
    }
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Select Product to Order")) {
                    Picker("Product", selection: $selectedInventoryId) {
                        Text("Select a Product").tag(UUID?.none)
                        ForEach(inventoryVM.inventoryList) { product in
                            Text("\(product.name) (Stock: \(product.stockQuantity))")
                                .tag(product.productId as UUID?)
                        }
                    }
                }
                
                Section(header: Text("Quantity to Order")) {
                    TextField("Quantity", text: $quantityToOrderStr)
                        .keyboardType(.numberPad)
                }
                
                Section {
                    Button(action: placeOrder) {
                        if inventoryVM.isLoading {
                            ProgressView()
                        } else {
                            Text("Place Order")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .appPrimaryButtonChrome(enabled: selectedInventoryId != nil && !quantityToOrderStr.isEmpty)
                        }
                    }
                    .disabled(selectedInventoryId == nil || quantityToOrderStr.isEmpty || inventoryVM.isLoading)
                }
            }
            .scrollContentBackground(.hidden)
            .background(BoutiqueTheme.background.ignoresSafeArea())
            .navigationTitle("Order Stock")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.light, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: {
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .foregroundColor(BoutiqueTheme.textPrimary)
                    }
                }
            }
            .tint(.appAccent)
        }
    }
    
    private func placeOrder() {
        guard let id = selectedInventoryId, let quantity = Int(quantityToOrderStr), quantity > 0 else { return }
        inventoryVM.orderStock(productId: id, quantity: quantity)
        presentationMode.wrappedValue.dismiss()
    }
}
