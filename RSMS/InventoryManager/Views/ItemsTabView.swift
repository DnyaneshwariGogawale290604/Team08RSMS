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
        case all = "All"
        case available = "Available"
        case reserved = "Reserved"
        case inTransit = "In Transit"
        case underRepair = "Under Repair"
        case missingScan = "Missing Scan"
        case recent = "Recent"
        case sold = "Sold"

        var systemImage: String {
            switch self {
            case .all:
                return "shippingbox"
            case .available:
                return "checkmark.circle"
            case .reserved:
                return "bookmark"
            case .inTransit:
                return "arrow.left.arrow.right.circle"
            case .underRepair:
                return "wrench.and.screwdriver"
            case .missingScan:
                return "clock.badge.exclamationmark"
            case .recent:
                return "clock.arrow.circlepath"
            case .sold:
                return "bag"
            }
        }
    }

    public init(categoryFilterMagic: Binding<String?>, repairFilter: Binding<RepairFilter>) {
        self._categoryFilterMagic = categoryFilterMagic
        self._repairFilter = repairFilter
    }

    private var filteredCategories: [String] {
        viewModel.categories.filter { category in
            if viewModel.filteredItemCount(for: category, filter: repairFilter) == 0 {
                return false
            }
            if let filter = categoryFilterMagic, category != filter {
                return false
            }
            return matchesSearch(category)
        }
    }

    public var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                VStack(spacing: 16) {
                    searchBar
                    activeFiltersRow

                    if viewModel.isLoading && filteredCategories.isEmpty {
                        ProgressView("Loading items…")
                            .tint(.appAccent)
                            .foregroundColor(.appSecondaryText)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if filteredCategories.isEmpty {
                        ContentUnavailableLabel(
                            title: "No Categories",
                            subtitle: "Try another search or filter.",
                            icon: "shippingbox"
                        )
                        .padding(.horizontal, 16)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 14) {
                                ForEach(filteredCategories, id: \.self) { category in
                                    NavigationLink(
                                        destination: ItemsListFilteredView(
                                            category: category,
                                            viewModel: viewModel,
                                            repairFilter: repairFilter
                                        )
                                    ) {
                                        categoryCard(for: category)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 104)
                            .padding(.top, 2)
                        }
                        .refreshable {
                            await reloadItems()
                        }
                    }
                }
                .padding(.top, 14)

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
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        Task { await reloadItems() }
                    } label: {
                        AppToolbarGlyph(systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.plain)
                }
            }
            .task {
                await reloadItems()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: NSNotification.Name("ExceptionResolved"))
            ) { _ in
                Task {
                    await reloadItems()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .inventoryManagerDataDidChange)) { _ in
                Task {
                    await reloadItems()
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
            .onReceive(
                NotificationCenter.default.publisher(for: NSNotification.Name("StartAuditSession"))
            ) { note in
                if let session = note.userInfo?["session"] as? AuditSession {
                    self.activeAuditSession = session
                    self.presentSheet(.auditScanner)
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.appAccent)

            TextField("Search names, RFIDs, serials...", text: $searchText)
                .textInputAutocapitalization(.never)
                .foregroundColor(.appPrimaryText)

            Button(action: {
                presentSheet(.addScan)
            }) {
                AppToolbarGlyph(systemImage: "barcode.viewfinder", backgroundColor: .appAccent)
            }
            .buttonStyle(.plain)
        }
        .padding(.leading, 16)
        .padding(.vertical, 10)
        .padding(.trailing, 10)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal, 16)
    }

    private var activeFiltersRow: some View {
        VStack(spacing: 0) {
            // ── Status filter chips ────────────────────────────
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(RepairFilter.allCases, id: \.self) { filter in
                        let isActive = repairFilter == filter
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                repairFilter = filter
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: filter.systemImage)
                                    .font(.system(size: 11, weight: .bold))
                                Text(filter.rawValue)
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundColor(isActive ? .white : .appAccent)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(isActive ? Color.appAccent : Color.white)
                                    .shadow(
                                        color: Color.black.opacity(isActive ? 0.14 : 0.05),
                                        radius: isActive ? 4 : 2, x: 0, y: 2
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isActive)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }

            // ── Active category chip + clear ──────────────────
            if let cat = categoryFilterMagic {
                HStack(spacing: 8) {
                    Image(systemName: "folder.fill")
                        .font(.caption2.bold())
                        .foregroundColor(.appAccent)
                    Text(cat)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.appPrimaryText)
                    Spacer()
                    Button {
                        categoryFilterMagic = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.appSecondaryText)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.luxurySurface)
            }
        }
    }

    private func categoryCard(for category: String) -> some View {
        let count = viewModel.filteredItemCount(for: category, filter: repairFilter)

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.luxurySurface)
                    .frame(width: 48, height: 48)

                Image(systemName: "folder.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.appAccent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(category)
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(.appPrimaryText)

                Text("\(count) item\(count == 1 ? "" : "s")")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.appSecondaryText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundColor(.appSecondaryText)
        }
        .padding(18)
        .background(Color.appCard)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 4)
    }

    private func matchesSearch(_ category: String) -> Bool {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return true }

        return category.localizedCaseInsensitiveContains(query)
            || viewModel.inventoryItems.contains { item in
                let itemCategory = item.category.isEmpty ? "General" : item.category
                guard itemCategory == category else { return false }
                return item.productName.localizedCaseInsensitiveContains(query)
                    || item.id.localizedCaseInsensitiveContains(query)
                    || item.serialId.localizedCaseInsensitiveContains(query)
                    || (item.assetTag?.localizedCaseInsensitiveContains(query) ?? false)
            }
    }

    private func reloadItems() async {
        await viewModel.loadDashboardData()
    }
}

public struct ItemsListFilteredView: View {
    @ObservedObject var viewModel: InventoryDashboardViewModel
    let category: String
    let repairFilter: ItemsTabView.RepairFilter
    @Environment(\.presentationMode) var presentationMode

    // Per-row scan state tracking
    @State private var scanningItemId: String? = nil
    @State private var scanErrorId: String? = nil

    public init(
        category: String, viewModel: InventoryDashboardViewModel,
        repairFilter: ItemsTabView.RepairFilter
    ) {
        self.category = category
        self.viewModel = viewModel
        self.repairFilter = repairFilter
    }

    public var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            if filteredItems.isEmpty {
                ContentUnavailableLabel(
                    title: "No Items",
                    subtitle: "No items match the current filter.",
                    icon: "shippingbox"
                )
                .padding(.horizontal, 16)
            } else {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 14) {
                        ForEach(filteredItems) { item in
                            NavigationLink(
                                destination: ItemDetailSupabaseView(item: item, viewModel: viewModel)
                            ) {
                                ItemRowCard(
                                    item: item,
                                    isScanning: scanningItemId == item.id,
                                    onScan: { performQuickScan(item: item) }
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 36)
                }
                .refreshable {
                    await viewModel.loadDashboardData()
                }
            }
        }
        .navigationTitle(category)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    AppToolbarGlyph(systemImage: "chevron.left", backgroundColor: .appAccent)
                }
                .buttonStyle(.plain)
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    Task { await viewModel.loadDashboardData() }
                } label: {
                    AppToolbarGlyph(systemImage: "arrow.clockwise", backgroundColor: .appAccent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var filteredItems: [InventoryItem] {
        viewModel.inventoryItems
            .filter { item in
                let itemCategory = item.category.isEmpty ? "General" : item.category
                return itemCategory == category && viewModel.matches(item, filter: repairFilter)
            }
            .sorted { lhs, rhs in
                let leftDate = lhs.lastScannedAt ?? lhs.timestamp
                let rightDate = rhs.lastScannedAt ?? rhs.timestamp
                return leftDate > rightDate
            }
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

struct ItemRowCard: View {
    let item: InventoryItem
    let isScanning: Bool
    let onScan: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                HStack(spacing: 8) {
                    Circle()
                        .fill(statusColor(for: item.status))
                        .frame(width: 9, height: 9)
                        .padding(.top, 7)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.productName)
                            .font(.system(size: 18, weight: .bold, design: .serif))
                            .foregroundColor(.appPrimaryText)
                            .lineLimit(1)

                        Label(item.id, systemImage: "wave.3.right")
                            .font(.caption.weight(.medium))
                            .foregroundColor(.appSecondaryText)
                    }
                }

                Spacer()

                ItemStatusBadge(status: item.status)
            }

            HStack(spacing: 10) {
                Label(scanSubtitle, systemImage: scanSubtitleIcon)
                    .font(.caption.weight(.medium))
                    .foregroundColor(scanSubtitleColor)

                if item.authenticityStatus != .verified {
                    Label(item.authenticityStatus.rawValue, systemImage: "checkmark.seal")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.appBrown)
                }

                Spacer(minLength: 0)
            }

            HStack(alignment: .center) {
                if let due = item.nextScanDueAt {
                    Text("Next scan \(due.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundColor(Date() > due ? .appBrown : .appSecondaryText)
                } else {
                    Text("Ready for next inventory check")
                        .font(.caption)
                        .foregroundColor(.appSecondaryText)
                }

                Spacer()

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
                            Text(isScanning ? "Scanning…" : "Scan")
                                .font(.caption.bold())
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(item.scanStatus == .overdue ? Color.appBrown : Color.appAccent)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isScanning)
                }
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
    }

    private func statusColor(for status: ItemStatus) -> Color {
        switch status {
        case .available: return .appAccent
        case .reserved: return .appBrown
        case .underRepair: return .red
        case .inTransit: return .luxuryDeepAccent
        case .scrapped, .sold: return .gray
        }
    }

    private var scanSubtitle: String {
        switch item.scanStatus {
        case .ok:
            return "Scan up to date"
        case .dueSoon:
            return "Scan due soon"
        case .overdue:
            return "Scan overdue"
        }
    }

    private var scanSubtitleIcon: String {
        switch item.scanStatus {
        case .ok:
            return "checkmark.circle"
        case .dueSoon:
            return "clock"
        case .overdue:
            return "exclamationmark.triangle"
        }
    }

    private var scanSubtitleColor: Color {
        switch item.scanStatus {
        case .ok:
            return .appAccent
        case .dueSoon:
            return .appBrown
        case .overdue:
            return .red
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
        case .ok: return .appAccent
        case .dueSoon: return .appBrown
        case .overdue: return .red
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
    @State private var showingReturnSheet = false
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
                    LabeledContent(
                        "Last Scanned",
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
                            LabeledContent(
                                "ETA", value: eta.formatted(date: .abbreviated, time: .omitted))
                            if eta < Date() && ticket.status != .completed
                                && ticket.status != .scrapped
                            {
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
                    NavigationLink(
                        destination: RepairTicketDetailView(item: $item, viewModel: viewModel)
                    ) {
                        Label("View Repair Ticket", systemImage: "doc.text.viewfinder")
                            .foregroundColor(.appAccent)
                    }
                } else if item.status == .sold {
                    Button(action: { showingReturnSheet = true }) {
                        Label("Raise Return", systemImage: "arrow.uturn.backward.circle")
                            .foregroundColor(.appAccent)
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
        .sheet(isPresented: $showingReturnSheet) {
            RaiseReturnRequestView(item: item, viewModel: viewModel)
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
                                .foregroundColor(cert.status == .valid ? .appAccent : .red)
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

    private func performScan() {
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
        case .scanned: return "wave.3.right.circle.fill"
        case .repairCreated: return "wrench.and.screwdriver.fill"
        case .repairClosed: return "checkmark.seal.fill"
        case .moved: return "mappin.and.ellipse"
        case .statusChanged: return "arrow.triangle.2.circlepath"
        case .added: return "plus.circle.fill"
        case .flaggedMissing: return "exclamationmark.triangle.fill"
        }
    }

    private func iconColor(for action: AuditLogAction) -> Color {
        switch action {
        case .scanned: return .appAccent
        case .repairCreated: return .appBrown
        case .repairClosed: return .luxuryDeepAccent
        case .moved: return .appBrown
        case .statusChanged: return .luxuryDeepAccent
        case .added: return .appAccent
        case .flaggedMissing: return .appBrown
        }
    }

    private func save(_ updatedItem: InventoryItem) {
        Task {
            do {
                try await DataService.shared.updateInventoryItem(item: updatedItem)
                await viewModel.loadDashboardData()
                self.item = updatedItem
                NotificationCenter.default.post(name: .inventoryManagerDataDidChange, object: nil)
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
        case .available: return .appAccent
        case .reserved: return .appBrown
        case .underRepair: return .red
        case .inTransit: return .luxuryDeepAccent
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
        case .verified: return .appAccent
        case .pending: return .appBrown
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

    let issueTypes = [
        "Broken Clasp", "Scratch Removal", "Stone Replacement", "Polishing", "Sizing",
        "Mechanical Failure", "Other",
    ]

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
                        DatePicker(
                            "Target Date", selection: $eta, in: Date()...,
                            displayedComponents: .date)
                    }
                }

                Section {
                    Button(action: submitRepair) {
                        Text("Submit for Repair")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canSubmit ? Color.appAccent : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .disabled(!canSubmit)
                }
            }
            .navigationTitle("Mark for Repair")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        AppToolbarGlyph(systemImage: "xmark", backgroundColor: .appAccent)
                    }
                    .buttonStyle(.plain)
                }
            }
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
                NotificationCenter.default.post(name: .inventoryManagerDataDidChange, object: nil)
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

    var revertTransitions: [RepairStatus] {
        switch currentStatus {
        case .created: return []
        case .diagnosed: return [.created]
        case .inRepair: return [.diagnosed]
        case .qaCheck: return [.inRepair]
        case .failed: return [.inRepair]
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
                        LabeledContent(
                            "ETA", value: eta.formatted(date: .abbreviated, time: .omitted))
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

                if !revertTransitions.isEmpty {
                    Section(header: Text("Revert Status").headingStyle()) {
                        ForEach(revertTransitions, id: \.self) { prevStatus in
                            Button(action: {
                                updateStatus(to: prevStatus)
                            }) {
                                HStack {
                                    Image(systemName: "arrow.uturn.backward.circle.fill")
                                    Text("Revert to \(prevStatus.rawValue)")
                                    Spacer()
                                }
                                .foregroundColor(.orange)
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
                    if let idx = viewModel.inventoryItems.firstIndex(where: {
                        $0.id == rescanned.id
                    }) {
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
                NotificationCenter.default.post(name: .inventoryManagerDataDidChange, object: nil)
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
        case .completed: return .appAccent
        case .failed, .scrapped: return .red
        default: return .luxuryDeepAccent
        }
    }
}

public struct RaiseReturnRequestView: View {
    let item: InventoryItem
    @ObservedObject var viewModel: InventoryDashboardViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var selectedReason = "Customer Return"
    @State private var additionalNotes = ""
    @State private var isSubmitting = false
    @State private var errorText: String?

    private let returnReasons = [
        "Customer Return",
        "Quality Concern",
        "Transit Damage",
        "Wrong Product Delivered",
        "Other",
    ]

    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Return Details").headingStyle()) {
                    Picker("Reason", selection: $selectedReason) {
                        ForEach(returnReasons, id: \.self) { reason in
                            Text(reason).tag(reason)
                        }
                    }

                    TextField("Notes (Optional)", text: $additionalNotes, axis: .vertical)
                        .lineLimit(2...4)
                }

                if let errorText {
                    Section {
                        Text(errorText)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Raise Return")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        AppToolbarGlyph(systemImage: "xmark", backgroundColor: .appAccent)
                    }
                    .buttonStyle(.plain)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        submitReturn()
                    } label: {
                        AppToolbarGlyph(
                            systemImage: isSubmitting ? "hourglass" : "checkmark",
                            enabled: !isSubmitting,
                            backgroundColor: .appAccent
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSubmitting)
                }
            }
        }
    }

    private var finalReason: String {
        let notes = additionalNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !notes.isEmpty else { return selectedReason }
        return "\(selectedReason): \(notes)"
    }

    private func submitReturn() {
        guard !isSubmitting else { return }
        isSubmitting = true
        errorText = nil

        Task {
            do {
                guard let orderId = try await resolveOrderId() else {
                    await MainActor.run {
                        errorText = "No linked sales order was found for this item yet."
                        isSubmitting = false
                    }
                    return
                }

                try await DataService.shared.createReturnRequest(
                    orderId: orderId,
                    productId: item.productId,
                    reason: finalReason
                )

                AuditService.shared.log(
                    itemId: item.id,
                    action: .statusChanged,
                    metadata: "Raised return request: \(selectedReason)"
                )
                NotificationCenter.default.post(name: .inventoryManagerDataDidChange, object: nil)

                await MainActor.run {
                    isSubmitting = false
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    errorText = "Unable to raise return: \(error.localizedDescription)"
                    isSubmitting = false
                }
            }
        }
    }

    private func resolveOrderId() async throws -> UUID? {
        let sales = viewModel.sales.isEmpty ? try await DataService.shared.fetchSales() : viewModel.sales
        let orderIds = sales.map(\.id)
        let orderItems = try await DataService.shared.fetchOrderItems(orderIds: orderIds)
        let matchingOrderIds = Set(
            orderItems.compactMap { orderItem in
                orderItem.productId == item.productId ? orderItem.orderId : nil
            }
        )

        return sales.first(where: { matchingOrderIds.contains($0.id) })?.id
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

    let availableCategories = [
        "Ring", "Necklace", "Bracelet", "Watch", "Handbag", "Earring", "Pendant", "Other",
    ]

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
                        LabeledContent(
                            "Category",
                            value: product.category.isEmpty ? "General" : product.category
                        )
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
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        AppToolbarGlyph(systemImage: "xmark", backgroundColor: .appAccent)
                    }
                    .buttonStyle(.plain)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        saveItem()
                    } label: {
                        AppToolbarGlyph(
                            systemImage: "checkmark",
                            enabled: canSave,
                            backgroundColor: .appAccent
                        )
                    }
                    .buttonStyle(.plain)
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
                    NotificationCenter.default.post(name: .inventoryManagerDataDidChange, object: nil)
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

// MARK: - Add Certification View

public struct AddCertificationView: View {
    let item: InventoryItem
    @ObservedObject var viewModel: InventoryDashboardViewModel
    var onComplete: (Certification) -> Void

    @Environment(\.presentationMode) var presentationMode

    @State private var selectedType: String = "Authenticity"
    @State private var certificateNumber: String = ""
    @State private var issuedBy: String = ""
    @State private var issuedDate: Date = Date()
    @State private var expiryDate: Date = Calendar.current.date(
        byAdding: .year, value: 1, to: Date())!
    @State private var hasExpiry: Bool = true
    @State private var attachDocument = false

    @State private var isUploading = false
    @State private var showingFileImporter = false
    @State private var selectedFileURL: URL? = nil
    @State private var errorText: String? = nil

    let certificationTypes = ["Authenticity", "Warranty", "Appraisal", "Export License", "Other"]

    public var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Certification Details").headingStyle()) {
                    Picker("Type", selection: $selectedType) {
                        ForEach(certificationTypes, id: \.self) { type in
                            Text(type).tag(type)
                        }
                    }

                    TextField(referenceCertificateNumber, text: $certificateNumber)
                    TextField("RSMS Certification Authority", text: $issuedBy)
                }

                Section(header: Text("Timeline").headingStyle()) {
                    DatePicker("Issued Date", selection: $issuedDate, displayedComponents: .date)

                    Toggle("Has Expiry Date", isOn: $hasExpiry)
                    if hasExpiry {
                        DatePicker(
                            "Expiry Date", selection: $expiryDate, displayedComponents: .date)
                    }
                }

                Section(header: Text("Document").headingStyle()) {
                    Toggle("Attach Supporting Document", isOn: $attachDocument)

                    if let url = selectedFileURL, attachDocument {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.appAccent)
                            Text(url.lastPathComponent)
                                .font(.subheadline)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button(action: { selectedFileURL = nil }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                            }
                        }
                    } else {
                        Button(action: { showingFileImporter = true }) {
                            HStack {
                                Image(systemName: "paperclip")
                                Text("Select Document (PDF/Image)")
                            }
                            .foregroundColor(attachDocument ? .appAccent : .appSecondaryText)
                        }
                        .disabled(!attachDocument)
                    }

                    Text(
                        attachDocument
                            ? "Attach a certificate file now or save and upload supporting proof later."
                            : "A certification record can be saved without attaching a document."
                    )
                    .font(.caption)
                    .foregroundColor(.appSecondaryText)
                    .padding(.vertical, 4)
                }

                if let error = errorText {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                Section {
                    Button(action: saveCertification) {
                        HStack {
                            Spacer()
                            if isUploading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Save Certification")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(canSave ? Color.appAccent : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(!canSave || isUploading)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .navigationTitle("Add Certification")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: seedReferenceValuesIfNeeded)
            .onChange(of: attachDocument) { _, newValue in
                if !newValue {
                    selectedFileURL = nil
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        AppToolbarGlyph(systemImage: "xmark", backgroundColor: .appAccent)
                    }
                    .buttonStyle(.plain)
                }
            }
            .fileImporter(
                isPresented: $showingFileImporter,
                allowedContentTypes: [.pdf, .image],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    selectedFileURL = urls.first
                case .failure(let error):
                    errorText = error.localizedDescription
                }
            }
        }
    }

    private var trimmedCertificateNumber: String {
        certificateNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedIssuedBy: String {
        issuedBy.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSave: Bool {
        !trimmedCertificateNumber.isEmpty && !trimmedIssuedBy.isEmpty
    }

    private func saveCertification() {
        guard canSave else { return }

        isUploading = true
        errorText = nil

        Task {
            do {
                let publicUrl: String?

                if attachDocument {
                    guard let fileURL = selectedFileURL else {
                        await MainActor.run {
                            errorText = "Please select a certificate document."
                            isUploading = false
                        }
                        return
                    }

                    guard fileURL.startAccessingSecurityScopedResource() else {
                        await MainActor.run {
                            errorText = "Permission denied to read file."
                            isUploading = false
                        }
                        return
                    }

                    defer { fileURL.stopAccessingSecurityScopedResource() }

                    let data = try Data(contentsOf: fileURL)
                    let fileName = fileURL.lastPathComponent
                    publicUrl = try await DataService.shared.uploadCertificateDocument(
                        data: data, fileName: fileName)
                } else {
                    publicUrl = nil
                }

                let certificationStatus: CertificationStatus
                if hasExpiry, expiryDate <= Date() {
                    certificationStatus = .expired
                } else {
                    certificationStatus = .valid
                }

                let newCert = Certification(
                    itemId: item.id,
                    type: selectedType,
                    certificateNumber: trimmedCertificateNumber,
                    issuedBy: trimmedIssuedBy,
                    issuedDate: issuedDate,
                    expiryDate: hasExpiry ? expiryDate : nil,
                    documentURL: publicUrl,
                    status: certificationStatus
                )

                try await DataService.shared.insertCertification(certification: newCert)

                AuditService.shared.log(
                    itemId: item.id,
                    action: .statusChanged,
                    metadata: "Added \(selectedType) certification: \(trimmedCertificateNumber)"
                )
                NotificationCenter.default.post(name: .inventoryManagerDataDidChange, object: nil)

                await MainActor.run {
                    onComplete(newCert)
                    presentationMode.wrappedValue.dismiss()
                }
            } catch {
                await MainActor.run {
                    errorText = "Failed to save certification: \(error.localizedDescription)"
                    isUploading = false
                }
            }
        }
    }

    private var referenceCertificateNumber: String {
        let sanitizedItemId = item.id.replacingOccurrences(
            of: "[^A-Za-z0-9]",
            with: "",
            options: .regularExpression
        )
        let suffix = String(sanitizedItemId.suffix(6))
        return "CERT-\(suffix)-\(Calendar.current.component(.year, from: Date()))"
    }

    private func seedReferenceValuesIfNeeded() {
        if trimmedCertificateNumber.isEmpty {
            certificateNumber = referenceCertificateNumber
        }

        if trimmedIssuedBy.isEmpty {
            issuedBy = "RSMS Certification Authority"
        }
    }
}
