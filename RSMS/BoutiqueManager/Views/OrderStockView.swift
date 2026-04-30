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
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(.black)
                            .frame(width: 34, height: 34)
                            .background(Color.white)
                            .clipShape(Circle())
                            .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                    }
                }
            }
            .tint(.appAccent)
        }
        .dismissKeyboardOnTap()
    }
    
    private func placeOrder() {
        guard let id = selectedInventoryId, let quantity = Int(quantityToOrderStr), quantity > 0 else {
            Haptics.shared.error()
            return
        }
        Haptics.shared.success()
        inventoryVM.orderStock(productId: id, quantity: quantity)
        presentationMode.wrappedValue.dismiss()
    }
}
