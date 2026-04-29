import SwiftUI
import UniformTypeIdentifiers

public struct ItemsTabView: View {
    @StateObject private var viewModel = InventoryDashboardViewModel()
    @Binding var categoryFilterMagic: String?
    
    @State private var searchText = ""
    enum ActiveSheet: String, Identifiable {
        case addManual, addScan, auditScanner, addFolder, auditSetup
        var id: String { rawValue }
    }
    @State private var activeSheet: ActiveSheet?
    @State private var activeAuditSession: AuditSession?
    
    private func presentSheet(_ sheet: ActiveSheet) {
        // Delay presentation slightly to avoid conflict with the Menu dismissal animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.activeSheet = sheet
        }
    }
    
    @Binding var repairFilter: RepairFilter
    
    public enum RepairFilter: String, CaseIterable {
        case all          = "All"
        case available    = "Available"
        case underRepair  = "Under Repair"
        case missingScan  = "Missing Scan"
    }
    
    public init(categoryFilterMagic: Binding<String?>, repairFilter: Binding<RepairFilter>) {
        self._categoryFilterMagic = categoryFilterMagic
        self._repairFilter = repairFilter
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
                            presentSheet(.addScan)
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
                            if viewModel.filteredItemCount(for: text, filter: repairFilter) == 0 { return false }
                            if let filter = categoryFilterMagic { return text == filter }
                            if !searchText.isEmpty {
                                return text.localizedCaseInsensitiveContains(searchText)
                                    || viewModel.products.contains {
                                        $0.category == text
                                            && ($0.name.localizedCaseInsensitiveContains(searchText)
                                                || $0.id.uuidString.localizedCaseInsensitiveContains(searchText))
                                    }
                            }
                            return true
                        }, id: \.self) { category in
                            NavigationLink(destination: ItemsListFilteredView(category: category, viewModel: viewModel, repairFilter: repairFilter)) {
                                HStack {
                                    Image(systemName: "folder.fill")
                                        .foregroundColor(.appAccent)
                                        .font(.title2)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(category)
                                            .font(.headline)
                                            .foregroundColor(.appPrimaryText)
                                        let count = viewModel.filteredItemCount(for: category, filter: repairFilter)
                                        let missing = viewModel.inventoryItems.filter {
                                            ($0.category.isEmpty ? "General" : $0.category) == category
                                                && $0.scanStatus == .overdue
                                        }.count
                                        if missing > 0 {
                                            Text("\(missing) missing scan")
                                                .font(.caption2)
                                                .foregroundColor(.appBrown)
                                        }
                                    }
                                    Spacer()
                                    let count = viewModel.filteredItemCount(for: category, filter: repairFilter)
                                    Text("\(count)")
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
                            Button(action: { presentSheet(.addManual) }) {
                                Label("Add Manual", systemImage: "doc.badge.plus")
                            }
                            Button(action: { presentSheet(.addScan) }) {
                                Label("Add via Scan", systemImage: "barcode.viewfinder")
                            }
                            Button(action: { presentSheet(.auditScanner) }) {
                                Label("Audit Location Scan", systemImage: "location.viewfinder")
                            }
                            Button(action: { presentSheet(.addFolder) }) {
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
            .navigationBarTitleDisplayMode(.large)

            .task {
                await viewModel.loadDashboardData()
            }
            .refreshable {
                await viewModel.loadDashboardData()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ExceptionResolved"))) { _ in
                Task {
                    await viewModel.loadDashboardData()
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .addManual:
                    AddItemManualView(viewModel: viewModel)
                case .addScan:
                    AddItemScanView(viewModel: viewModel)
                case .auditScanner:
                    RFIDScannerView(activeSession: activeAuditSession, isPresentedAsSheet: true)
                        .onDisappear { activeAuditSession = nil }
                case .addFolder:
                    AddFolderView(viewModel: viewModel)
                case .auditSetup:
                    AuditSessionSetupView(viewModel: viewModel)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartAuditSession"))) { note in
                if let session = note.userInfo?["session"] as? AuditSession {
                    self.activeAuditSession = session
                    self.presentSheet(.auditScanner)
                }
            }
        }
    }
}

public struct ItemsListFilteredView: View {
    @ObservedObject var viewModel: InventoryDashboardViewModel
    let category: String
    let repairFilter: ItemsTabView.RepairFilter

    // Per-row scan state tracking
    @State private var scanningItemId: String? = nil
    @State private var scanErrorId: String? = nil

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
                case .all:        statusMatch = item.status != .scrapped && item.status != .sold
                case .available:  statusMatch = item.status == .available
                case .underRepair: statusMatch = item.status == .underRepair
                case .missingScan: statusMatch = item.scanStatus == .overdue
                }
                return categoryMatch && statusMatch
            }

            if filteredItems.isEmpty {
                ContentUnavailableLabel(
                    title: "No Items",
                    subtitle: "No items match the current filter.",
                    icon: "shippingbox"
                )
                .listRowBackground(Color.clear)
            }

            ForEach(filteredItems) { item in
                NavigationLink(destination: ItemDetailSupabaseView(item: item, viewModel: viewModel)) {
                    ItemRowCard(
                        item: item,
                        isScanning: scanningItemId == item.id,
                        onScan: { performQuickScan(item: item) }
                    )
                }
                .listRowBackground(Color.appCard)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
        .listStyle(.plain)
        .navigationTitle(category)
    }

    private func performQuickScan(item: InventoryItem) {
        guard scanningItemId == nil else { return }
        scanningItemId = item.id
        Task {
            do {
                let updated = try await AuditService.shared.recordScan(item: item)
                if let idx = viewModel.inventoryItems.firstIndex(where: { $0.id == updated.id }) {
                    viewModel.inventoryItems[idx] = updated
                }
            } catch {
                scanErrorId = item.id
            }
            await MainActor.run { scanningItemId = nil }
        }
    }
}

// MARK: - Item Row Card

private struct ItemRowCard: View {
    let item: InventoryItem
    let isScanning: Bool
    let onScan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Top row: name + status badge
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor(for: item.status))
                    .frame(width: 8, height: 8)

                Text(item.productName)
                    .font(.headline)
                    .foregroundColor(.appPrimaryText)
                    .lineLimit(1)

                Spacer()

                ScanStatusBadge(status: item.scanStatus)

                if item.status == .underRepair {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            // RFID + Location row
            HStack {
                Label(item.id, systemImage: "wave.3.right")
                    .font(.caption2)
                    .foregroundColor(.appSecondaryText)
                Spacer()
                Text(item.location)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.appBorder.opacity(0.3))
                    .cornerRadius(4)
            }

            // Scan timing row
            HStack(spacing: 12) {
                if let last = item.lastScannedAt {
                    Label(
                        "Scanned: \(last.formatted(date: .abbreviated, time: .shortened))",
                        systemImage: "checkmark.circle"
                    )
                    .font(.caption2)
                    .foregroundColor(.appSecondaryText)
                } else {
                    Label("Never scanned", systemImage: "exclamationmark.circle")
                        .font(.caption2)
                        .foregroundColor(.appBrown)
                }

                Spacer()

                if let due = item.nextScanDueAt {
                    let isOverdue = Date() > due
                    Label(
                        "Due: \(due.formatted(date: .abbreviated, time: .shortened))",
                        systemImage: isOverdue ? "exclamationmark.triangle" : "clock"
                    )
                    .font(.caption2)
                    .foregroundColor(isOverdue ? .appBrown : .orange)
                }
            }

            // Scan now button (only for non-repair, non-scrapped items)
            if item.status != .underRepair && item.status != .scrapped && item.status != .sold {
                Button(action: onScan) {
                    HStack(spacing: 6) {
                        if isScanning {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: "barcode.viewfinder")
                        }
                        Text(isScanning ? "Scanning…" : "Scan Now")
                            .font(.caption.bold())
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(item.scanStatus == .overdue ? Color.appBrown : Color.appAccent)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(isScanning)
            }
        }
        .padding(.vertical, 8)
    }

    private func statusColor(for status: ItemStatus) -> Color {
        switch status {
        case .available:   return .green
        case .reserved:    return .orange
        case .underRepair: return .red
        case .inTransit:   return .blue
        case .scrapped, .sold: return .gray
        }
    }
}

// MARK: - Scan Status Badge

public struct ScanStatusBadge: View {
    let status: ScanStatus

    public var body: some View {
        Text(status.label)
            .font(.caption2.bold())
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(6)
    }

    private var color: Color {
        switch status {
        case .ok:      return .green
        case .dueSoon: return .orange
        case .overdue: return .appBrown
        }
    }
}

// MARK: - Reusable empty state

private struct ContentUnavailableLabel: View {
    let title: String
    let subtitle: String
    let icon: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(.appBorder)
            Text(title)
                .font(.headline)
                .foregroundColor(.appPrimaryText)
            Text(subtitle)
                .font(.caption)
                .foregroundColor(.appSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}


public struct ItemDetailSupabaseView: View {
    @State var item: InventoryItem
    @ObservedObject var viewModel: InventoryDashboardViewModel
    @State private var showingRepairSheet = false
    @State private var isScanning = false
    @State private var auditLogs: [AuditLog] = []
    @State private var certifications: [Certification] = []
    @State private var showingAddCertificationSheet = false
    @Environment(\.presentationMode) var presentationMode


    public var body: some View {
        Form {
            // ── 1. Item Details ──────────────────────────────────────
            Section(header: Text("Item Details").headingStyle()) {
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
                
                if let tag = item.assetTag {
                    LabeledContent("Asset Tag", value: tag)
                }
            }

            // ── 1.5. Certification Info ──────────────────────────────
            certificationInfoSection


            // ── 2. Scan & Audit Info ─────────────────────────────────
            Section(header: Text("Scan & Audit Info").headingStyle()) {
                if let last = item.lastScannedAt {
                    LabeledContent("Last Scanned",
                                   value: last.formatted(date: .abbreviated, time: .standard))
                } else {
                    HStack {
                        Text("Last Scanned")
                        Spacer()
                        Text("Never")
                            .foregroundColor(.red)
                    }
                }

                if let due = item.nextScanDueAt {
                    HStack {
                        Text("Next Scan Due")
                        Spacer()
                        Text(due.formatted(date: .abbreviated, time: .shortened))
                            .foregroundColor(Date() > due ? .red : .primary)
                    }
                } else {
                    LabeledContent("Next Scan Due", value: "—")
                }

                HStack {
                    Text("Scan Status")
                    Spacer()
                    ScanStatusBadge(status: item.scanStatus)
                }

                LabeledContent("Total Scans", value: "\(item.scanCount)")

                // Scan Now CTA — hidden for repair/scrapped/sold
                if item.status != .underRepair && item.status != .scrapped && item.status != .sold {
                    Button(action: performScan) {
                        HStack {
                            if isScanning {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .frame(width: 16, height: 16)
                            } else {
                                Image(systemName: "barcode.viewfinder")
                            }
                            Text(isScanning ? "Scanning…" : "Scan Now")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(item.scanStatus == .overdue ? Color.appBrown : Color.appAccent)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(isScanning)
                }
            }

            // ── 3. Repair Information ────────────────────────────────
            if let ticket = item.activeTicket {
                Section(header: Text("Repair Information").headingStyle()) {
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
                                    .background(Color.appBrown)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }
            }

            // ── 4. Actions ───────────────────────────────────────────
            Section {
                if item.status == .available {
                    Button(action: { showingRepairSheet = true }) {
                        Label("Raise Repair Ticket", systemImage: "wrench.and.screwdriver")
                            .foregroundColor(.appBrown)
                    }
                } else if item.status == .underRepair {
                    NavigationLink(destination: RepairTicketDetailView(item: $item, viewModel: viewModel)) {
                        Label("View Repair Ticket", systemImage: "doc.text.viewfinder")
                            .foregroundColor(.blue)
                    }
                }
            }

            // ── 5. Activity History ──────────────────────────────────
            if !auditLogs.isEmpty {
                Section(header: Text("Activity History").headingStyle()) {
                    ForEach(auditLogs) { log in
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: iconName(for: log.action))
                                .foregroundColor(iconColor(for: log.action))
                                .frame(width: 20)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(log.action.rawValue)
                                    .font(.subheadline)
                                    .foregroundColor(.appPrimaryText)
                                if let meta = log.metadata, !meta.isEmpty {
                                    Text(meta)
                                        .font(.caption2)
                                        .foregroundColor(.appSecondaryText)
                                }
                                Text(log.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundColor(.appSecondaryText)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
        .navigationTitle("Item Details")
        .sheet(isPresented: $showingRepairSheet) {
            RepairInputView(item: $item, viewModel: viewModel)
        }
        .sheet(isPresented: $showingAddCertificationSheet) {
            AddCertificationView(item: item, viewModel: viewModel) { newCert in
                Task { await loadCertifications() }
            }
        }
        .task {
            // Load audit trail from Supabase
            await AuditService.shared.loadLogs(for: item.id)
            auditLogs = AuditService.shared.logs(for: item.id)
            
            // Load certifications
            await loadCertifications()
        }
        .onReceive(AuditService.shared.$auditLogs) { _ in
            auditLogs = AuditService.shared.logs(for: item.id)
        }
    }

    private var certificationInfoSection: some View {
        Section(header: Text("Certification Info").headingStyle()) {
            HStack {
                Text("Authenticity")
                Spacer()
                AuthenticityBadge(status: item.authenticityStatus)
            }

            if certifications.isEmpty {
                Text("No certifications attached.")
                    .font(.caption)
                    .foregroundColor(.appSecondaryText)
                    .padding(.vertical, 4)
            } else {
                ForEach(certifications) { cert in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(cert.type)
                                .font(.subheadline.bold())
                            Spacer()
                            Text(cert.status.rawValue)
                                .font(.caption2.bold())
                                .foregroundColor(cert.status == .valid ? .green : .red)
                        }
                        
                        Text("No: \(cert.certificateNumber)")
                            .font(.caption)
                            .foregroundColor(.appSecondaryText)
                        
                        if let expiry = cert.expiryDate {
                            Text("Expires: \(expiry.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption2)
                                .foregroundColor(expiry < Date() ? .red : .appSecondaryText)
                        }
                        
                        if let url = cert.documentURL, let link = URL(string: url) {
                            Link(destination: link) {
                                Label("View Document", systemImage: "doc.text.fill")
                                    .font(.caption.bold())
                                    .foregroundColor(.appAccent)
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Button(action: { showingAddCertificationSheet = true }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Certification")
                }
                .foregroundColor(.appAccent)
            }
        }
    }

    private func loadCertifications() async {
        do {
            certifications = try await DataService.shared.fetchCertifications(for: item.id)
            // Re-validate item authenticity status
            let updatedItem = try await AuditService.shared.refreshItemAuthenticity(item: item)
            self.item = updatedItem
            if let idx = viewModel.inventoryItems.firstIndex(where: { $0.id == updatedItem.id }) {
                viewModel.inventoryItems[idx] = updatedItem
            }
        } catch {
            print("Failed to load certifications: \(error)")
        }
    }

    }
}
        isScanning = true
        Task {
            do {
                let updated = try await AuditService.shared.recordScan(item: item)
                self.item = updated
                if let idx = viewModel.inventoryItems.firstIndex(where: { $0.id == updated.id }) {
                    viewModel.inventoryItems[idx] = updated
                }
                auditLogs = AuditService.shared.logs(for: item.id)
            } catch {
                print("Scan failed: \(error)")
            }
            isScanning = false
        }
    }

    private func iconName(for action: AuditLogAction) -> String {
        switch action {
        case .scanned:        return "wave.3.right.circle.fill"
        case .repairCreated:  return "wrench.and.screwdriver.fill"
        case .repairClosed:   return "checkmark.seal.fill"
        case .moved:          return "mappin.and.ellipse"
        case .statusChanged:  return "arrow.triangle.2.circlepath"
        case .added:          return "plus.circle.fill"
        case .flaggedMissing: return "exclamationmark.triangle.fill"
        }
    }

    private func iconColor(for action: AuditLogAction) -> Color {
        switch action {
        case .scanned:        return .green
        case .repairCreated:  return .appBrown
        case .repairClosed:   return .blue
        case .moved:          return .orange
        case .statusChanged:  return .purple
        case .added:          return .appAccent
        case .flaggedMissing: return .appBrown
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

public struct AuthenticityBadge: View {
    let status: AuthenticityStatus
    
    public var body: some View {
        Text(status.rawValue)
            .font(.caption2.bold())
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(8)
    }
    
    private var color: Color {
        switch status {
        case .verified: return .green
        case .pending: return .orange
        case .failed: return .red
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
                Section(header: Text("Repair Details").headingStyle()) {
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
                
                Section(header: Text("Assignment & Timeline").headingStyle()) {
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
                // Audit trail entry
                AuditService.shared.log(
                    itemId: updatedItem.id,
                    action: .repairCreated,
                    metadata: updatedItem.activeTicket?.issueType
                )
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
                Section(header: Text("Ticket Info").headingStyle()) {
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
                    Section(header: Text("Update Status").headingStyle()) {
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
                    try await DataService.shared.finalizeRepairTicket(
                        ticketId: ticketId,
                        newStatus: newStatus,
                        itemId: updatedItem.id,
                        itemStatus: updatedItem.status
                    )
                    // Repair closed → reset lastScannedAt so cycle count restarts
                    let rescanned = try await AuditService.shared.recordScan(item: updatedItem)
                    if let idx = viewModel.inventoryItems.firstIndex(where: { $0.id == rescanned.id }) {
                        viewModel.inventoryItems[idx] = rescanned
                    }
                    AuditService.shared.log(
                        itemId: updatedItem.id,
                        action: .repairClosed,
                        metadata: newStatus.rawValue
                    )
                } else {
                    if let ticket = item.activeTicket {
                        var updatedTicket = ticket
                        updatedTicket.status = newStatus
                        updatedTicket.updatedAt = Date()
                        try await DataService.shared.updateRepairTicket(ticket: updatedTicket)
                    }
                    try await DataService.shared.updateInventoryItem(item: updatedItem)
                    AuditService.shared.log(
                        itemId: updatedItem.id,
                        action: .statusChanged,
                        metadata: newStatus.rawValue
                    )
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
            Section(header: Text("Details").headingStyle()) {
                LabeledContent("Name", value: item.productName)
                LabeledContent("Batch", value: item.batchNo)
                LabeledContent("Serial", value: item.serialId)
                LabeledContent("RFID Tag", value: item.id)
                LabeledContent("Location", value: item.location)
                LabeledContent("Status", value: item.status.rawValue)
            }
            
            Section(header: Text("Scan History").headingStyle()) {
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
    
    public init(viewModel: InventoryDashboardViewModel) {
        self.viewModel = viewModel
        self._location = State(initialValue: viewModel.locations.first ?? "Warehouse")
    }
    
    @State private var selectedProduct: Product? = nil
    @State private var rfid = "RFID-\(Int.random(in: 1000...9999))"
    @State private var batchNo = "B-MANUAL"
    @State private var assetTag = ""
    @State private var location = "Warehouse"

    @State private var errorText: String?
    
    let availableCategories = ["Ring", "Necklace", "Bracelet", "Watch", "Handbag", "Earring", "Pendant", "Other"]
    
    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Product Details").headingStyle()) {
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
                
                Section(header: Text("Identification").headingStyle()) {
                    HStack {
                        Text("RFID Tag")
                            .foregroundColor(.appSecondaryText)
                        Spacer()
                        Text(rfid)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.appAccent)
                    }
                    
                    TextField("Batch Number", text: $batchNo)
                    TextField("Asset Tag (e.g. RSMS-2024-001)", text: $assetTag)
                }

                
                Section(header: Text("Location").headingStyle()) {
                    Picker("Storage Location", selection: $location) {
                        ForEach(viewModel.locations, id: \.self) { loc in
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
            }
            .navigationTitle("Add Manual Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { presentationMode.wrappedValue.dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { saveItem() } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(canSave ? .primary : Color.gray)
                    }
                    .disabled(!canSave)
                }
            }
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
                    // Inventory managers own warehouse stock, not store inventory.
                    try await DataService.shared.incrementWarehouseInventoryForCurrentManager(
                        productId: product.id,
                        quantity: 1
                    )
                    
                    // Add specific serialized item for the new repair/item feature
                    let newItem = InventoryItem(
                        id: rfid,
                        serialId: "SN-\(Int.random(in: 1000...9999))",
                        productId: product.id,
                        batchNo: batchNo,
                        productName: product.name,
                        category: product.category.isEmpty ? "General" : product.category,
                        location: location,
                        status: .available,
                        assetTag: assetTag.isEmpty ? nil : assetTag
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
