import SwiftUI

public struct StoreFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var viewModel: StoreViewModel

    @State private var generatedStoreId = UUID()
    @State private var name = ""
    @State private var location = ""
    @State private var address = ""
    @State private var salesTargetStr = ""
    @State private var openingDate = Date()
    @State private var storeStatus: StoreDraftStatus = .active

    @State private var availableProducts: [Product] = []
    @State private var selectedInventory: [InventoryDraftItem] = []
    @State private var isLoadingProducts = false
    @State private var isSaving = false
    @State private var showingProductPicker = false

    @State private var errorMessage: String?
    @State private var showingErrorAlert = false

    private let storeService = StoreService.shared
    private let inventoryService = StoreInventoryService.shared
    private let productService = ProductService.shared

    public init(viewModel: StoreViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color(.systemGroupedBackground).ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        headerView
                        storeDetailsSection
                        addressSection
                        inventorySection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 36)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingProductPicker) {
                StoreProductPickerSheet(
                    products: remainingProducts,
                    isLoading: isLoadingProducts,
                    onSelect: { product in
                        addInventoryItem(product)
                        showingProductPicker = false
                    }
                )
            }
            .alert("Unable to Save Store", isPresented: $showingErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage ?? "Unknown error")
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
            
            Text("Add Store")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(.black)
            
            Spacer()
            
            Button("Save") {
                Task { await saveStore() }
            }
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(canSave ? .black : .gray.opacity(0.4))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.white)
            .clipShape(Capsule())
            .disabled(!canSave)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var storeDetailsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Store Information")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.appSecondaryText)

            whiteCard {
                inlineTextField("Location", text: $name)

                divider

                detailRow(title: "Opening Date") {
                    DatePicker("", selection: $openingDate, displayedComponents: .date)
                        .labelsHidden()
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGroupedBackground))
                        .cornerRadius(8)
                }

                divider

                detailRow(title: "Status") {
                    Menu {
                        Picker("Status", selection: $storeStatus) {
                            ForEach(StoreDraftStatus.allCases, id: \.self) { status in
                                Text(status.displayName).tag(status)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(storeStatus.displayName)
                                .foregroundColor(.black)
                            Image(systemName: "chevron.up.chevron.down")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                        }
                    }
                }

                divider

                inlineTextField("Sales Target (Optional)", text: $salesTargetStr, keyboardType: .decimalPad)
            }

        }
    }

    private var addressSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Address")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.appSecondaryText)

            whiteCard {
                TextEditor(text: $address)
                    .frame(minHeight: 110)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                    .overlay(alignment: .topLeading) {
                        if address.isEmpty {
                            Text("Street, landmark, city, postal code")
                                .font(.system(size: 16))
                                .foregroundColor(.gray.opacity(0.5))
                                .padding(.top, 8)
                                .padding(.leading, 5)
                        }
                    }
            }

        }
    }

    private var inventorySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Inventory Details")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.appSecondaryText)

            whiteCard {
                VStack(alignment: .leading, spacing: 16) {
                    Button {
                        Task { await openProductPicker() }
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .semibold))
                            Text("Add Product")
                                .font(.system(size: 17, weight: .medium))
                        }
                        .foregroundColor(.black)
                    }
                    .padding(.vertical, 4)

                    if !selectedInventory.isEmpty {
                        divider
                    }

                    if selectedInventory.isEmpty {
                        Text("Tap Add Product to fetch products from the catalog and set opening baseline quantities.")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .lineSpacing(4)
                    } else {
                        ForEach(Array(selectedInventory.enumerated()), id: \.element.id) { index, item in
                            inventoryRow(index: index, item: item)
                            if index < selectedInventory.count - 1 {
                                divider
                            }
                        }
                    }
                }
            }
        }
    }

    private func inventoryRow(index: Int, item: InventoryDraftItem) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(index + 1)) \(item.product.name)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
                Text(item.product.category)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }

            Spacer()

            HStack(spacing: 0) {
                Button {
                    decrementQuantity(for: item.id)
                } label: {
                    quantityControlLabel(systemName: "minus")
                }

                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 1, height: 22)

                Text("\(item.quantity)")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(minWidth: 34)

                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: 1, height: 22)

                Button {
                    incrementQuantity(for: item.id)
                } label: {
                    quantityControlLabel(systemName: "plus")
                }
            }
            .padding(4)
            .background(Color.brandOffWhite)
            .clipShape(Capsule())
        }
    }

    private func quantityControlLabel(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.black)
            .frame(width: 34, height: 28)
    }

    private func removeInventoryItems(at offsets: IndexSet) {
        selectedInventory.remove(atOffsets: offsets)
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
    }

    private func detailRow<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Text(title)
                .font(.system(size: 16))
                .foregroundColor(.black)

            Spacer(minLength: 12)

            content()
        }
    }

    private func inlineTextField(
        _ placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType = .default,
        alignment: TextAlignment = .leading
    ) -> some View {
        TextField(placeholder, text: text)
            .multilineTextAlignment(alignment)
            .keyboardType(keyboardType)
            .font(.system(size: 16))
            .foregroundColor(.black)
    }

    private var divider: some View {
        Divider()
            .background(Color.gray.opacity(0.15))
    }

    private var shortStoreId: String {
        generatedStoreId.uuidString.prefix(8).uppercased()
    }

    private var canSave: Bool {
        !isSaving &&
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var remainingProducts: [Product] {
        let selectedIds = Set(selectedInventory.map(\.product.id))
        return availableProducts.filter { !selectedIds.contains($0.id) }
    }

    private func openProductPicker() async {
        if availableProducts.isEmpty {
            await fetchCatalogProducts()
        }

        if !isLoadingProducts {
            showingProductPicker = true
        }
    }

    private func fetchCatalogProducts() async {
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            availableProducts = try await productService.fetchProducts().sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func addInventoryItem(_ product: Product) {
        selectedInventory.append(InventoryDraftItem(product: product, quantity: 1))
    }

    private func incrementQuantity(for id: UUID) {
        guard let index = selectedInventory.firstIndex(where: { $0.id == id }) else { return }
        selectedInventory[index].quantity += 1
    }

    private func decrementQuantity(for id: UUID) {
        guard let index = selectedInventory.firstIndex(where: { $0.id == id }) else { return }

        if selectedInventory[index].quantity > 1 {
            selectedInventory[index].quantity -= 1
        } else {
            selectedInventory.remove(at: index)
        }
    }

    private func saveStore() async {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, !trimmedLocation.isEmpty else {
            presentError("Store name and location are required.")
            return
        }

        isSaving = true
        defer { isSaving = false }

        do {
            let formatter = DateFormatter()
            formatter.calendar = .current
            formatter.locale = .current
            formatter.timeZone = .current
            formatter.dateFormat = "yyyy-MM-dd"

            let newStore = Store(
                id: generatedStoreId,
                name: trimmedName,
                location: trimmedLocation.isEmpty ? "Main" : trimmedLocation,
                brandId: nil,
                salesTarget: Double(salesTargetStr),
                createdAt: nil,
                openingDate: formatter.string(from: openingDate),
                status: storeStatus.rawValue,
                address: trimmedAddress.isEmpty ? nil : trimmedAddress
            )

            try await storeService.createStore(newStore)

            let inventoryPayload = selectedInventory.map { (productId: $0.product.id, quantity: $0.quantity) }
            if !inventoryPayload.isEmpty {
                try await inventoryService.assignProducts(storeId: generatedStoreId, items: inventoryPayload)
            }

            await viewModel.fetchStores()
            dismiss()
        } catch {
            presentError(error.localizedDescription)
        }
    }

    private func presentError(_ message: String) {
        errorMessage = message
        showingErrorAlert = true
    }
}

private enum StoreDraftStatus: String, CaseIterable {
    case active
    case inactive
    case underMaintenance = "under_maintenance"

    var displayName: String {
        switch self {
        case .active:
            return "Active"
        case .inactive:
            return "Inactive"
        case .underMaintenance:
            return "Under maintenance"
        }
    }
}

private struct InventoryDraftItem: Identifiable {
    let id = UUID()
    let product: Product
    var quantity: Int
}

private struct StoreProductPickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    let products: [Product]
    let isLoading: Bool
    let onSelect: (Product) -> Void

    @State private var searchText = ""

    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    LoadingView(message: "Loading catalog...")
                } else if filteredProducts.isEmpty {
                    EmptyStateView(
                        icon: "bag",
                        title: "No Products",
                        message: products.isEmpty ? "No catalog products are available." : "No matching products found."
                    )
                } else {
                    List(filteredProducts) { product in
                        Button {
                            onSelect(product)
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(product.name)
                                        .foregroundColor(.appPrimaryText)
                                    Text(product.category)
                                        .font(.caption)
                                        .foregroundColor(.appSecondaryText)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .searchable(text: $searchText, prompt: "Search catalog")
            .navigationTitle("Catalog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var filteredProducts: [Product] {
        guard !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return products
        }

        return products.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText)
        }
    }
}
