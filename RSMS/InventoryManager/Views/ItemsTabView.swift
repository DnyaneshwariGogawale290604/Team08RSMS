import SwiftUI

public struct ItemsTabView: View {
    @StateObject private var viewModel = InventoryDashboardViewModel()
    @Binding var categoryFilterMagic: String?
    
    @State private var searchText = ""
    @State private var showingAddManual = false
    @State private var showingAddScan = false
    @State private var showingAuditScanner = false
    @State private var showingAddFolder = false
    
    public init(categoryFilterMagic: Binding<String?>) {
        self._categoryFilterMagic = categoryFilterMagic
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass").foregroundColor(.gray)
                        TextField("Search names, RFIDs, serials...", text: $searchText)
                        
                        Button(action: {
                            // Dummy barcode open
                            showingAddScan = true
                        }) {
                            Image(systemName: "barcode.viewfinder")
                                .foregroundColor(.appAccent)
                        }
                    }
                    .padding()
                    .background(Color.appCard)
                    .cornerRadius(10)
                    .padding()
                    
                    // Folder & Items List
                    List {
                        let categories = viewModel.categories
                        
                        ForEach(categories.filter { text in 
                            if let filter = categoryFilterMagic { return text == filter }
                            if !searchText.isEmpty { return text.localizedCaseInsensitiveContains(searchText) || viewModel.products.contains { $0.category == text && ($0.name.localizedCaseInsensitiveContains(searchText) || $0.id.uuidString.localizedCaseInsensitiveContains(searchText)) }
                            }
                            return true
                        }, id: \.self) { category in
                            NavigationLink(destination: ItemsListFilteredView(category: category, viewModel: viewModel)) {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(.appAccent)
                                        .font(.title2)
                                    Text(category)
                                        .font(.headline)
                                        .foregroundColor(.appPrimaryText)
                                    Spacer()
                                    Text("\(viewModel.availableItems(for: category))")
                                        .foregroundColor(.appSecondaryText)
                                }
                                .padding(.vertical, 8)
                            }
                            .listRowBackground(Color.appCard)
                        }
                        
                        // Clear filter
                        if categoryFilterMagic != nil {
                            Button("Clear Category Filter") {
                                categoryFilterMagic = nil
                            }
                            .foregroundColor(.red)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.insetGrouped)
                }
                
                // FAB Multi-Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Menu {
                            Button(action: { showingAddManual = true }) {
                                Label("Add Manual", systemImage: "doc.badge.plus")
                            }
                            Button(action: { showingAddScan = true }) {
                                Label("Add via Scan", systemImage: "barcode.viewfinder")
                            }
                            Button(action: { showingAuditScanner = true }) {
                                Label("Audit Location Scan", systemImage: "location.viewfinder")
                            }
                            Button(action: { showingAddFolder = true }) {
                                Label("Add Folder", systemImage: "folder.badge.plus")
                            }
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.white)
                                .padding(20)
                                .background(Color.appAccent)
                                .clipShape(Circle())
                                .shadow(radius: 5)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Items")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.loadDashboardData()
            }
            .refreshable {
                await viewModel.loadDashboardData()
            }
            .sheet(isPresented: $showingAddManual) {
                AddItemManualView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingAddScan) {
                AddItemScanView()
            }
            .sheet(isPresented: $showingAuditScanner) {
                RFIDScannerView()
            }
            .sheet(isPresented: $showingAddFolder) {
                AddFolderView()
            }
        }
    }
}

public struct ItemsListFilteredView: View {
    @ObservedObject var viewModel: InventoryDashboardViewModel
    let category: String
    
    public init(category: String, viewModel: InventoryDashboardViewModel) {
        self.category = category
        self.viewModel = viewModel
    }
    
    public var body: some View {
        List {
            let categoryProducts = viewModel.products.filter { ($0.category.isEmpty ? "General" : $0.category) == category }
            let productIds = Set(categoryProducts.map { $0.id })
            
            ForEach(viewModel.storeInventory.filter { inv in
                if let pid = inv.productId { return productIds.contains(pid) }
                return false
            }) { item in
                let product = viewModel.products.first(where: { $0.id == item.productId })
                NavigationLink(destination: ItemDetailSupabaseView(item: item, product: product)) {
                    VStack(alignment: .leading) {
                        Text(product?.name ?? "Unknown Item").font(.headline)
                        Text("ID: \(item.id.uuidString)").font(.caption).foregroundColor(.appSecondaryText)
                        HStack {
                            Text("Available")
                                .font(.caption2.bold())
                                .foregroundColor(.green)
                            Spacer()
                            Text("Qty: \(item.quantity)").font(.caption2).foregroundColor(.gray)
                        }
                    }
                }
            }
        }
        .navigationTitle(category)
    }
}

public struct ItemDetailSupabaseView: View {
    let item: StoreInventory
    let product: Product?
    
    public var body: some View {
        Form {
            Section(header: Text("Details")) {
                LabeledContent("Name", value: product?.name ?? "Unknown")
                LabeledContent("Category", value: product?.category ?? "General")
                LabeledContent("Price", value: "$\(product?.price ?? 0)")
                LabeledContent("Quantity", value: "\(item.quantity)")
                LabeledContent("Storage ID", value: item.id.uuidString)
            }
        }
        .navigationTitle("Item Details")
    }
}

public struct ItemDetailView: View {
    let item: InventoryItem
    
    public var body: some View {
        Form {
            Section(header: Text("Details")) {
                LabeledContent("Name", value: item.productName)
                LabeledContent("Batch", value: item.batchNo)
                LabeledContent("Serial", value: item.serialId)
                LabeledContent("RFID Tag", value: item.id)
                LabeledContent("Location", value: item.location)
                LabeledContent("Status", value: item.status.rawValue)
            }
            
            Section(header: Text("Scan History")) {
                HStack {
                    Image(systemName: "arrow.down.right.circle.fill").foregroundColor(.green)
                    Text("Ingested via Warehouse Scan")
                    Spacer()
                    Text("Today").font(.caption).foregroundColor(.gray)
                }
            }
        }
        .navigationTitle("Item Details")
    }
}

public struct AddItemManualView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var viewModel: InventoryDashboardViewModel
    
    @State private var name = ""
    @State private var rfid = "RFID-\(Int.random(in: 1000...9999))"
    @State private var category = ""
    @State private var batchNo = "B-MANUAL"
    @State private var location = "Warehouse"
    @State private var errorText: String?
    
    let availableCategories = ["Ring", "Necklace", "Bracelet", "Watch", "Handbag", "Earring", "Pendant", "Other"]
    let availableLocations = ["Warehouse", "Main Vault", "Showroom Floor", "Paris Boutique", "Tokyo Boutique", "New York Store", "Scanning Bay"]
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Product Details")) {
                    TextField("Product Name", text: $name)
                    
                    Picker("Category", selection: $category) {
                        Text("Select Category").tag("")
                        ForEach(availableCategories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                }
                
                Section(header: Text("Identification")) {
                    HStack {
                        Text("RFID Tag")
                            .foregroundColor(.appSecondaryText)
                        Spacer()
                        Text(rfid)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.appAccent)
                    }
                    
                    TextField("Batch Number", text: $batchNo)
                }
                
                Section(header: Text("Location")) {
                    Picker("Storage Location", selection: $location) {
                        ForEach(availableLocations, id: \.self) { loc in
                            Text(loc).tag(loc)
                        }
                    }
                }
                
                if let err = errorText {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                            Text(err)
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                    }
                }
                
                Section {
                    Button(action: saveItem) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Save Item")
                        }
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(canSave ? .white : .gray)
                        .padding()
                        .background(canSave ? Color.appAccent : Color.appBorder)
                        .cornerRadius(12)
                    }
                    .disabled(!canSave)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("Add Manual Item")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark")
                }
            )
        }
    }
    
    private var canSave: Bool {
        !name.isEmpty && !category.isEmpty
    }
    
    private func saveItem() {
        guard canSave else { return }
        
        Task {
            do {
                // Find or create product ID? 
                // For simplicity, we assume the product exists or we find the first one with the same name
                let products = viewModel.products.filter { $0.name == name }
                if let product = products.first {
                    try await DataService.shared.createInventoryItem(productId: product.id, quantity: 1)
                    await viewModel.loadDashboardData()
                    presentationMode.wrappedValue.dismiss()
                } else {
                    errorText = "Product '\(name)' not found in database. Please create the product first."
                }
            } catch {
                errorText = "Failed to save to Supabase: \(error.localizedDescription)"
            }
        }
    }
}
