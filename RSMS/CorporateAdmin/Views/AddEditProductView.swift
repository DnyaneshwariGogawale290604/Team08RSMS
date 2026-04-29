import SwiftUI
import UIKit
import PhotosUI

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
    @State private var isSaving = false
    @State private var variantDrafts: [ProductVariantDraft] = []

    public init(viewModel: ProductViewModel, editingProduct: Product? = nil) {
        self.viewModel = viewModel
        self.editingProduct = editingProduct
    }

    public var body: some View {
        NavigationView {
            Form {
                Section(header: sectionHeader("Basic Info")) {
                    TextField("Product Name", text: $name)
                        .textInputAutocapitalization(.words)
                    HStack {
                        TextField("Category", text: $category)
                            .textInputAutocapitalization(.words)

                        if !availableCategories.isEmpty {
                            Menu {
                                ForEach(availableCategories, id: \.self) { categoryName in
                                    Button(categoryName) {
                                        category = categoryName
                                    }
                                }
                            } label: {
                                Image(systemName: "chevron.down.circle")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
                .listRowBackground(CatalogTheme.card)

                Section(header: variantSectionHeader) {
                    if variantDrafts.count > 1 {
                        Button {
                            applyFirstVariantInfoToAll()
                        } label: {
                            Label("Same Info for All", systemImage: "text.badge.checkmark")
                        }
                    }

                    ForEach($variantDrafts) { $draft in
                        VariantEditorRow(draft: $draft, isBaseModel: draft.id == variantDrafts.first?.id) {
                            removeVariant(draft.id)
                        }
                    }

                    Button {
                        addVariant()
                    } label: {
                        Label("Add Variant", systemImage: "plus.circle.fill")
                    }
                    .disabled(variantDrafts.count >= 12)
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
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
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
                    variantDrafts = product.displayVariants.map {
                        ProductVariantDraft(
                            id: $0.id,
                            name: $0.name,
                            infoText: $0.infoText ?? "",
                            existingImageUrls: $0.imageUrls
                        )
                    }
                }

                if variantDrafts.isEmpty {
                    addBaseVariant()
                }
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

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundColor(CatalogTheme.primaryText)
            .textCase(nil)
    }

    private var variantSectionHeader: some View {
        HStack {
            sectionHeader("Variants")
            Spacer()
            Text("Base + variants, 1-5 images each")
                .font(.caption)
                .foregroundColor(CatalogTheme.secondaryText)
                .textCase(nil)
        }
    }

    private var availableCategories: [String] {
        Array(Set(viewModel.products.map { $0.category.trimmingCharacters(in: .whitespacesAndNewlines) }))
            .filter { !$0.isEmpty }
            .sorted()
    }

    private func addBaseVariant() {
        variantDrafts.append(ProductVariantDraft(name: "Base Model"))
    }

    private func addVariant() {
        variantDrafts.append(ProductVariantDraft(name: ""))
    }

    private func removeVariant(_ id: UUID) {
        guard id != variantDrafts.first?.id else { return }

        guard variantDrafts.count > 1 else {
            variantDrafts[0] = ProductVariantDraft(name: "Base Model")
            return
        }

        variantDrafts.removeAll { $0.id == id }
    }

    private func applyFirstVariantInfoToAll() {
        guard let firstInfo = variantDrafts.first?.infoText else { return }
        for index in variantDrafts.indices {
            variantDrafts[index].infoText = firstInfo
        }
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
            let variants = normalizedVariantInputs()
            if editingProduct == nil {
                didSave = await viewModel.addProduct(newProduct, image: nil, variants: variants)
            } else {
                didSave = await viewModel.updateProduct(newProduct, variants: variants)
            }

            if didSave {
                dismiss()
            } else {
                isSaving = false
            }
        }
    }

    private func normalizedVariantInputs() -> [ProductVariantDraftInput] {
        var drafts = variantDrafts
        if drafts.isEmpty {
            drafts = [ProductVariantDraft(name: "Base Model")]
        }

        let productName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if drafts[0].name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            drafts[0].name = productName.isEmpty ? "Base Model" : productName
        }

        return drafts.map(\.serviceInput)
    }
}

private struct ProductVariantDraft: Identifiable {
    var id: UUID = UUID()
    var name: String
    var infoText: String = ""
    var existingImageUrls: [String] = []
    var selectedImages: [UIImage] = []
    var pickerItems: [PhotosPickerItem] = []

    var serviceInput: ProductVariantDraftInput {
        ProductVariantDraftInput(
            id: id,
            name: name,
            infoText: infoText,
            existingImageUrls: existingImageUrls,
            newImages: selectedImages
        )
    }
}

private struct VariantEditorRow: View {
    @Binding var draft: ProductVariantDraft
    let isBaseModel: Bool
    let onRemove: () -> Void

    private var totalImageCount: Int {
        draft.existingImageUrls.count + draft.selectedImages.count
    }

    private var availableImageSlots: Int {
        max(0, 5 - totalImageCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                TextField(isBaseModel ? "Base model name" : "Variant name", text: $draft.name)
                    .textInputAutocapitalization(.words)

                if isBaseModel {
                    Text("Base")
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(CatalogTheme.imageBackground)
                        .clipShape(Capsule())
                } else {
                    Button(role: .destructive, action: onRemove) {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }

            TextField("Info text for this variant", text: $draft.infoText, axis: .vertical)
                .lineLimit(2...4)
                .textInputAutocapitalization(.sentences)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(draft.existingImageUrls, id: \.self) { imageUrl in
                        remotePreview(imageUrl)
                    }

                    ForEach(Array(draft.selectedImages.enumerated()), id: \.offset) { _, image in
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 64, height: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }

                    if totalImageCount < 5 {
                        PhotosPicker(
                            selection: $draft.pickerItems,
                            maxSelectionCount: availableImageSlots,
                            matching: .images
                        ) {
                            VStack(spacing: 6) {
                                Image(systemName: "photo.on.rectangle.angled")
                                Text("Images")
                                    .font(.caption2)
                            }
                            .foregroundColor(.accentColor)
                            .frame(width: 64, height: 64)
                            .background(CatalogTheme.imageBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            Text("\(totalImageCount)/5 images")
                .font(.caption)
                .foregroundColor(CatalogTheme.secondaryText)
        }
        .padding(.vertical, 6)
        .onChange(of: draft.pickerItems) { _, items in
            Task {
                await loadImages(from: items)
            }
        }
    }

    @ViewBuilder
    private func remotePreview(_ imageUrl: String) -> some View {
        if let url = URL(string: imageUrl) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    CatalogTheme.imageBackground
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    @MainActor
    private func loadImages(from items: [PhotosPickerItem]) async {
        guard availableImageSlots > 0 else {
            draft.pickerItems = []
            return
        }

        var loadedImages = draft.selectedImages

        for item in items {
            if loadedImages.count + draft.existingImageUrls.count >= 5 { break }
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                loadedImages.append(image)
            }
        }

        draft.selectedImages = Array(loadedImages.prefix(max(0, 5 - draft.existingImageUrls.count)))
        draft.pickerItems = []
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
