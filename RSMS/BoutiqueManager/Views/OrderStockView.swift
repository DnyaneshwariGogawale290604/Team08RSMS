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
                
                // Removed Place Order Section
            }
            .scrollContentBackground(.hidden)
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Order Stock")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(CatalogTheme.primaryText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Order") {
                        placeOrder()
                    }
                    .foregroundColor((selectedInventoryId != nil && !quantityToOrderStr.isEmpty) ? CatalogTheme.primaryText : Color.gray)
                    .disabled(selectedInventoryId == nil || quantityToOrderStr.isEmpty)
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
