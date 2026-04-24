import SwiftUI
import UIKit

public struct AddEditProductView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: ProductViewModel

    var editingProduct: Product?

    @State private var name: String = ""
    @State private var category: String = ""
    @State private var price: String = ""
    @State private var sku: String = ""
    @State private var makingPrice: String = ""
    @State private var taxPercentage: String = "18"
    @State private var isActive: Bool = true
    @State private var selectedImage: UIImage?
    @State private var showImagePicker = false
    @State private var isSaving = false

    public init(viewModel: ProductViewModel, editingProduct: Product? = nil) {
        self.viewModel = viewModel
        self.editingProduct = editingProduct
    }

    public var body: some View {
        NavigationView {
            Form {
                Section {
                    Button {
                        showImagePicker = true
                    } label: {
                        productImagePicker
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(CatalogTheme.card)
                }

                Section(header: sectionHeader("Basic Info")) {
                    TextField("Product Name", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Category", text: $category)
                        .textInputAutocapitalization(.words)
                }
                .listRowBackground(CatalogTheme.card)
                
                Section(header: sectionHeader("Pricing & Details")) {
                    TextField("Sale Price (₹)", text: $price)
                        .keyboardType(.decimalPad)
                    TextField("Making Price (₹)", text: $makingPrice)
                        .keyboardType(.decimalPad)
                    TextField("SKU", text: $sku)
                }
                .listRowBackground(CatalogTheme.card)

                Section(header: sectionHeader("Tax Configuration")) {
                    HStack {
                        Text("Tax Rate")
                            .foregroundColor(CatalogTheme.primaryText)
                        Spacer()
                        TextField("18", text: $taxPercentage)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                        Text("%")
                            .foregroundColor(CatalogTheme.secondaryText)
                    }

                    if let priceVal = Double(price), priceVal > 0,
                       let taxRate = Double(taxPercentage), taxRate >= 0 {
                        let taxAmount = priceVal * taxRate / 100
                        let total = priceVal + taxAmount
                        HStack {
                            Text("Tax Amount")
                                .foregroundColor(CatalogTheme.secondaryText)
                            Spacer()
                            Text(String(format: "₹%.2f", taxAmount))
                                .foregroundColor(CatalogTheme.primaryText)
                                .fontWeight(.medium)
                        }
                        HStack {
                            Text("Total Price (incl. tax)")
                                .foregroundColor(CatalogTheme.secondaryText)
                            Spacer()
                            Text(String(format: "₹%.2f", total))
                                .foregroundColor(.accentColor)
                                .fontWeight(.bold)
                        }
                    }
                }
                .listRowBackground(CatalogTheme.card)

                Section {
                    Toggle("Active Status", isOn: $isActive)
                        .tint(.accentColor)
                }
                .listRowBackground(CatalogTheme.card)
            }
            .scrollContentBackground(.hidden)
            .background(CatalogTheme.background.ignoresSafeArea())
            .tint(.accentColor)
            .navigationTitle(editingProduct == nil ? "Add Product" : "Edit Product")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(CatalogTheme.secondaryText)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(editingProduct == nil ? "Add" : "Save") {
                        guard !isSaving else { return }
                        isSaving = true
                        save()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundColor(name.isEmpty || price.isEmpty || isSaving ? CatalogTheme.secondaryText : .accentColor)
                    .disabled(name.isEmpty || price.isEmpty || isSaving)
                }
            }
            .onAppear {
                if let product = editingProduct {
                    name = product.name
                    category = product.category
                    price = String(product.price)
                    sku = product.sku ?? ""
                    makingPrice = product.makingPrice.map { String(format: "%.2f", $0) } ?? ""
                    isActive = product.isActive ?? true
                    if let existingTax = product.tax, product.price > 0 {
                        let rate = (existingTax / product.price) * 100
                        taxPercentage = String(format: "%.1f", rate)
                    }
                }
            }
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .alert(
                "Product Save Failed",
                isPresented: Binding(
                    get: { viewModel.errorMessage != nil },
                    set: { if !$0 { viewModel.errorMessage = nil } }
                )
            ) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "Unable to save product.")
            }
        }
    }

    @ViewBuilder
    private var productImagePicker: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(CatalogTheme.imageBackground)
                .frame(height: 180)

            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else if let imageUrl = editingProduct?.imageUrl,
                      !imageUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      let url = URL(string: imageUrl) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    ProgressView()
                        .tint(.accentColor)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 180)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            } else {
                uploadPlaceholder
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var uploadPlaceholder: some View {
        VStack(spacing: 10) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 30, weight: .regular))
                .foregroundColor(.accentColor)
            Text("Choose Product Image")
                .font(.subheadline)
                .foregroundColor(CatalogTheme.primaryText)
            Text("Photos will appear in the catalog cards.")
                .font(.footnote)
                .foregroundColor(CatalogTheme.secondaryText)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(CatalogTheme.primaryText)
            .textCase(nil)
    }

    private func save() {
        let priceVal = Double(price) ?? 0.0
        let taxRate = Double(taxPercentage) ?? 18.0
        let computedTax = priceVal * taxRate / 100
        let computedTotalPrice = priceVal + computedTax

        let newProduct = Product(
            id: editingProduct?.id ?? UUID(),
            name: name,
            brandId: editingProduct?.brandId,
            category: category,
            price: priceVal,
            sku: sku,
            makingPrice: Double(makingPrice),
            imageUrl: editingProduct?.imageUrl,
            isActive: isActive,
            tax: computedTax,
            totalPrice: computedTotalPrice
        )

        Task {
            let didSave: Bool
            if editingProduct == nil {
                didSave = await viewModel.addProduct(newProduct, image: selectedImage)
            } else {
                didSave = await viewModel.updateProduct(newProduct)
            }

            if didSave {
                dismiss()
            } else {
                isSaving = false
            }
        }
    }
}

private struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let parent: ImagePicker

        init(_ parent: ImagePicker) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.image = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.image = originalImage
            }

            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
