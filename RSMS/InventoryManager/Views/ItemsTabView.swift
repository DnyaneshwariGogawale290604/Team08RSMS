import SwiftUI

public struct ItemsTabView: View {
    @StateObject private var viewModel = InventoryDashboardViewModel()
    @Binding var categoryFilterMagic: String?
    
    @State private var searchText = ""
    @State private var showingAddManual = false
    @State private var showingAddScan = false
    @State private var showingAuditScanner = false
    @State private var showingAddFolder = false
    @State private var repairFilter: RepairFilter = .all
    
    public enum RepairFilter: String, CaseIterable {
        case all = "All"
        case available = "Available"
        case underRepair = "Under Repair"
    }
    
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
                    .cornerRadius(20)
                    .padding()
                    
                    // Filter Segmented Control
                    Picker("Filter", selection: $repairFilter) {
                        ForEach(RepairFilter.allCases, id: \.self) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.bottom, 10)
                    
                    // Folder & Items List
                    List {
                        let categories = viewModel.categories
                        
                        ForEach(categories.filter { text in 
                            // 1. Check if the folder is completely empty for the selected filter
                            if viewModel.filteredItemCount(for: text, filter: repairFilter) == 0 {
                                return false
                            }
                            
                            // 2. Check magic filter
                            if let filter = categoryFilterMagic { return text == filter }
                            
                            // 3. Check search text
                            if !searchText.isEmpty { return text.localizedCaseInsensitiveContains(searchText) || viewModel.products.contains { $0.category == text && ($0.name.localizedCaseInsensitiveContains(searchText) || $0.id.uuidString.localizedCaseInsensitiveContains(searchText)) }
                            }
                            
                            return true
                        }, id: \.self) { category in
                            NavigationLink(destination: ItemsListFilteredView(category: category, viewModel: viewModel, repairFilter: repairFilter)) {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(.appAccent)
                                        .font(.title2)
                                    Text(category)
                                        .font(.headline)
                                        .foregroundColor(.appPrimaryText)
                                    Spacer()
                                    Text("\(viewModel.filteredItemCount(for: category, filter: repairFilter))")
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
    let repairFilter: ItemsTabView.RepairFilter
    
    public init(category: String, viewModel: InventoryDashboardViewModel, repairFilter: ItemsTabView.RepairFilter) {
        self.category = category
        self.viewModel = viewModel
        self.repairFilter = repairFilter
    }
    
    public var body: some View {
        List {
            let filteredItems = viewModel.inventoryItems.filter { item in
                let categoryMatch = (item.category.isEmpty ? "General" : item.category) == category
                let statusMatch: Bool
                switch repairFilter {
                case .all: statusMatch = item.status != .scrapped && item.status != .sold
                case .available: statusMatch = item.status == .available
                case .underRepair: statusMatch = item.status == .underRepair
                }
                return categoryMatch && statusMatch
            }
            
            ForEach(filteredItems) { item in
                NavigationLink(destination: ItemDetailSupabaseView(item: item, viewModel: viewModel)) {
                    HStack(spacing: 12) {
                        // Status Indicator
                        Circle()
                            .fill(statusColor(for: item.status))
                            .frame(width: 10, height: 10)
                        
                        VStack(alignment: .leading) {
                            Text(item.productName).font(.headline)
                            Text("ID: \(item.id)").font(.caption).foregroundColor(.appSecondaryText)
                        }
                        
                        Spacer()
                        
                        if item.status == .underRepair {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        
                        Text(item.location)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.appBorder.opacity(0.3))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .navigationTitle(category)
    }
    
    private func statusColor(for status: ItemStatus) -> Color {
        switch status {
        case .available: return .black // or CatalogTheme.primary, let's use appPrimaryText
        case .reserved: return .orange
        case .underRepair: return .red
        case .inTransit: return .blue
        case .scrapped: return .gray
        case .sold: return .gray
        }
    }
}

public struct ItemDetailSupabaseView: View {
    @State var item: InventoryItem
    @ObservedObject var viewModel: InventoryDashboardViewModel
    @State private var showingRepairSheet = false
    @Environment(\.presentationMode) var presentationMode
    
    public var body: some View {
        Form {
            Section(header: Text("Item Details")) {
                LabeledContent("Name", value: item.productName)
                LabeledContent("Category", value: item.category)
                LabeledContent("RFID Tag", value: item.id)
                LabeledContent("Serial", value: item.serialId)
                LabeledContent("Location", value: item.location)
                
                HStack {
                    Text("Status")
                    Spacer()
                    ItemStatusBadge(status: item.status)
                }
            }
            
            if let ticket = item.activeTicket {
                Section(header: Text("Repair Information")) {
                    LabeledContent("Issue", value: ticket.issueType)
                    LabeledContent("Ticket Status", value: ticket.status.rawValue)
                    if let assigned = ticket.assignedTo {
                        LabeledContent("Assigned To", value: assigned)
                    }
                    if let eta = ticket.eta {
                        HStack {
                            LabeledContent("ETA", value: eta.formatted(date: .abbreviated, time: .omitted))
                            if eta < Date() && ticket.status != .completed && ticket.status != .scrapped {
                                Text("OVERDUE")
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(Color.red)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }
            
            Section {
                if item.status == .available {
                    Button(action: { showingRepairSheet = true }) {
                        Label("Raise Repair Ticket", systemImage: "wrench.and.screwdriver")
                            .foregroundColor(.red)
                    }
                } else if item.status == .underRepair {
                    NavigationLink(destination: RepairTicketDetailView(item: $item, viewModel: viewModel)) {
                        Label("View Repair Ticket", systemImage: "doc.text.viewfinder")
                            .foregroundColor(.blue)
                    }
                }
            }
        }
        .navigationTitle("Item Details")
        .sheet(isPresented: $showingRepairSheet) {
            RepairInputView(item: $item, viewModel: viewModel)
        }
    }
    
    private func save(_ updatedItem: InventoryItem) {
        Task {
            do {
                try await DataService.shared.updateInventoryItem(item: updatedItem)
                await viewModel.loadDashboardData()
                self.item = updatedItem
            } catch {
                print("Failed to update item: \(error)")
            }
        }
    }
}

public struct ItemStatusBadge: View {
    let status: ItemStatus
    
    public var body: some View {
        Text(status.rawValue)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.2))
            .foregroundColor(color)
            .cornerRadius(8)
    }
    
    private var color: Color {
        switch status {
        case .available: return .green
        case .reserved: return .orange
        case .underRepair: return .red
        case .inTransit: return .blue
        case .scrapped, .sold: return .gray
        }
    }
}

public struct RepairInputView: View {
    @Binding var item: InventoryItem
    @ObservedObject var viewModel: InventoryDashboardViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var issueType = ""
    @State private var notes = ""
    @State private var assignedTo = ""
    @State private var eta = Date().addingTimeInterval(86400 * 3)
    @State private var useETA = false
    
    let issueTypes = ["Broken Clasp", "Scratch Removal", "Stone Replacement", "Polishing", "Sizing", "Mechanical Failure", "Other"]
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Repair Details")) {
                    Picker("Issue Type", selection: $issueType) {
                        Text("Select Issue").tag("")
                        ForEach(issueTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }
                    
                    TextEditor(text: $notes)
                        .frame(height: 100)
                        .overlay(
                            Group {
                                if notes.isEmpty {
                                    Text("Add repair notes...")
                                        .foregroundColor(.gray)
                                        .padding(.leading, 4)
                                        .padding(.top, 8)
                                }
                            },
                            alignment: .topLeading
                        )
                }
                
                Section(header: Text("Assignment & Timeline")) {
                    TextField("Assign To (Optional)", text: $assignedTo)
                    
                    Toggle("Set ETA", isOn: $useETA)
                    
                    if useETA {
                        DatePicker("Target Date", selection: $eta, in: Date()..., displayedComponents: .date)
                    }
                }
                
                Section {
                    Button(action: submitRepair) {
                        Text("Submit for Repair")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canSubmit ? Color.red : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(!canSubmit)
                }
            }
            .navigationTitle("Mark for Repair")
            .navigationBarItems(trailing: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private var canSubmit: Bool {
        !issueType.isEmpty && !notes.isEmpty
    }
    
    private func submitRepair() {
        var updatedItem = item
        updatedItem.status = .underRepair
        updatedItem.activeTicket = RepairTicket(
            itemId: item.id,
            issueType: issueType,
            description: notes,
            status: .created,
            assignedTo: assignedTo.isEmpty ? nil : assignedTo,
            eta: useETA ? eta : nil,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        Task {
            do {
                if let newTicket = updatedItem.activeTicket {
                    try await DataService.shared.insertRepairTicket(ticket: newTicket)
                }
                try await DataService.shared.updateInventoryItem(item: updatedItem)
                await viewModel.loadDashboardData()
                self.item = updatedItem
                presentationMode.wrappedValue.dismiss()
            } catch {
                print("Failed to submit repair: \(error)")
            }
        }
    }
}

public struct RepairTicketDetailView: View {
    @Binding var item: InventoryItem
    @ObservedObject var viewModel: InventoryDashboardViewModel
    @Environment(\.presentationMode) var presentationMode
    
    // Status machine logic
    // created -> diagnosed -> inRepair -> qaCheck -> completed
    // inRepair -> failed -> scrapped
    
    var currentStatus: RepairStatus {
        item.activeTicket?.status ?? .created
    }
    
    var availableTransitions: [RepairStatus] {
        switch currentStatus {
        case .created: return [.diagnosed]
        case .diagnosed: return [.inRepair]
        case .inRepair: return [.qaCheck, .failed]
        case .qaCheck: return [.completed]
        case .failed: return [.scrapped]
        case .completed, .scrapped: return []
        }
    }
    
    public var body: some View {
        Form {
            if let ticket = item.activeTicket {
                Section(header: Text("Ticket Info")) {
                    LabeledContent("Item Name", value: item.productName)
                    LabeledContent("Issue Type", value: ticket.issueType)
                    LabeledContent("Description", value: ticket.description)
                    LabeledContent("Status", value: ticket.status.rawValue)
                    if let assigned = ticket.assignedTo {
                        LabeledContent("Assigned To", value: assigned)
                    }
                    if let eta = ticket.eta {
                        LabeledContent("ETA", value: eta.formatted(date: .abbreviated, time: .omitted))
                    }
                }
                
                if !availableTransitions.isEmpty {
                    Section(header: Text("Update Status")) {
                        ForEach(availableTransitions, id: \.self) { nextStatus in
                            Button(action: {
                                updateStatus(to: nextStatus)
                            }) {
                                HStack {
                                    Text("Move to \(nextStatus.rawValue)")
                                    Spacer()
                                    Image(systemName: "arrow.right.circle.fill")
                                }
                                .foregroundColor(color(for: nextStatus))
                            }
                        }
                    }
                }
                
                if currentStatus == .completed || currentStatus == .scrapped {
                    Section {
                        Text("This repair ticket is closed.")
                            .foregroundColor(.gray)
                            .italic()
                    }
                }
            } else {
                Text("No active repair ticket found.")
            }
        }
        .navigationTitle("Repair Ticket")
    }
    
    private func updateStatus(to newStatus: RepairStatus) {
        guard var ticket = item.activeTicket else { return }
        
        // Capture ticket ID BEFORE we nil it out — needed for DB finalization
        let ticketId = ticket.id
        
        ticket.status = newStatus
        var updatedItem = item
        updatedItem.activeTicket?.status = newStatus
        updatedItem.activeTicket?.updatedAt = Date()
        
        if newStatus == .completed {
            updatedItem.status = .available
            updatedItem.activeTicket = nil
        } else if newStatus == .scrapped {
            updatedItem.status = .scrapped
            updatedItem.activeTicket = nil
        }
        
        // --- SYNCHRONOUS local state update first ---
        if let index = viewModel.inventoryItems.firstIndex(where: { $0.id == updatedItem.id }) {
            viewModel.inventoryItems[index] = updatedItem
        }
        self.item = updatedItem
        
        if newStatus == .completed || newStatus == .scrapped {
            presentationMode.wrappedValue.dismiss()
        }
        
        // --- Async Supabase persist ---
        Task {
            do {
                if newStatus == .completed || newStatus == .scrapped {
                    // Use dedicated method that updates repair_tickets + inventory_items
                    try await DataService.shared.finalizeRepairTicket(
                        ticketId: ticketId,
                        newStatus: newStatus,
                        itemId: updatedItem.id,
                        itemStatus: updatedItem.status
                    )
                } else {
                    // Mid-workflow update: upsert ticket + update item status
                    if let ticket = item.activeTicket {
                        var updatedTicket = ticket
                        updatedTicket.status = newStatus
                        updatedTicket.updatedAt = Date()
                        try await DataService.shared.updateRepairTicket(ticket: updatedTicket)
                    }
                    try await DataService.shared.updateInventoryItem(item: updatedItem)
                }
                await viewModel.loadDashboardData()
                self.item = updatedItem
                if newStatus == .completed || newStatus == .scrapped {
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                print("Failed to update ticket: \(error)")
            }
        }
    }
    
    private func color(for status: RepairStatus) -> Color {
        switch status {
        case .completed: return .green
        case .failed, .scrapped: return .red
        default: return .blue
        }
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
    
    @State private var selectedProduct: Product? = nil
    @State private var rfid = "RFID-\(Int.random(in: 1000...9999))"
    @State private var batchNo = "B-MANUAL"
    @State private var location = "Warehouse"
    @State private var errorText: String?
    
    let availableCategories = ["Ring", "Necklace", "Bracelet", "Watch", "Handbag", "Earring", "Pendant", "Other"]
    let availableLocations = ["Warehouse", "Main Vault", "Showroom Floor", "Paris Boutique", "Tokyo Boutique", "New York Store", "Scanning Bay"]
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Product Details")) {
                    Picker("Select Product", selection: $selectedProduct) {
                        Text("Choose a product...").tag(nil as Product?)
                        ForEach(viewModel.products, id: \.id) { product in
                            Text(product.name).tag(product as Product?)
                        }
                    }
                    
                    if let product = selectedProduct {
                        LabeledContent("Category", value: product.category.isEmpty ? "General" : product.category)
                            .foregroundColor(.appSecondaryText)
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
        selectedProduct != nil
    }
    
    private func saveItem() {
        guard canSave else { return }
        
        Task {
            do {
                if let product = selectedProduct {
                    // Update aggregate inventory
                    try await DataService.shared.createInventoryItem(productId: product.id, quantity: 1)
                    
                    // Add specific serialized item for the new repair/item feature
                    let newItem = InventoryItem(
                        id: rfid,
                        serialId: "SN-\(Int.random(in: 1000...9999))",
                        productId: product.id,
                        batchNo: batchNo,
                        productName: product.name,
                        category: product.category.isEmpty ? "General" : product.category,
                        location: location,
                        status: .available
                    )
                    try await DataService.shared.insertInventoryItem(item: newItem)
                    
                    await viewModel.loadDashboardData()
                    presentationMode.wrappedValue.dismiss()
                } else {
                    errorText = "Please select a product."
                }
            } catch {
                errorText = "Failed to save to Supabase: \(error.localizedDescription)"
            }
        }
    }
}
