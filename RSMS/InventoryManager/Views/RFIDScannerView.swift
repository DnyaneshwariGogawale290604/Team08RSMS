import SwiftUI

// MARK: - Audit Scan Result Model

struct AuditScanResult: Identifiable {
    let id = UUID()
    let scannedAt: Date
    let rfid: String
    let item: InventoryItem?       // nil = not found in DB
    let updatedLocation: String?   // non-nil if location was changed
    
    var isFound: Bool { item != nil }
    
    var statusIcon: String {
        guard let item else { return "xmark.octagon.fill" }
        switch item.status {
        case .available:    return "checkmark.circle.fill"
        case .reserved:     return "bookmark.circle.fill"
        case .inTransit:    return "shippingbox.circle.fill"
        case .underRepair:  return "wrench.and.screwdriver.fill"
        case .scrapped:     return "trash.circle.fill"
        case .sold:         return "tag.circle.fill"
        }
    }
    
    var statusColor: Color {
        guard let item else { return .red }
        switch item.status {
        case .available:    return .green
        case .reserved:     return .orange
        case .inTransit:    return .blue
        case .underRepair:  return .red
        case .scrapped:     return .gray
        case .sold:         return .purple
        }
    }
}

// MARK: - RFIDScannerView

public struct RFIDScannerView: View {
    @Environment(\.presentationMode) var presentationMode
    
    // Input
    @State private var scanInput: String = ""
    @State private var selectedLocation: String = "Warehouse"
    @State private var updateLocationOnScan: Bool = false
    
    // DB-fetched locations
    @State private var availableLocations: [String] = ["Warehouse", "Main Vault", "Showroom Floor"]
    
    // Session state
    @State private var scanResults: [AuditScanResult] = []
    @State private var isScanning: Bool = false
    @State private var lastLookedUpItem: InventoryItem? = nil
    @State private var showItemDetail: Bool = false
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 16) {
                        
                        // MARK: Configuration Card
                        ReusableCardView {
                            VStack(alignment: .leading, spacing: 14) {
                                Label("Scanner Configuration", systemImage: "gear")
                                    .font(.headline)
                                    .foregroundColor(.appPrimaryText)
                                
                                Divider()
                                
                                // Location picker
                                HStack {
                                    Text("Audit Location")
                                        .font(.subheadline)
                                        .foregroundColor(.appSecondaryText)
                                    Spacer()
                                    Picker("Location", selection: $selectedLocation) {
                                        ForEach(availableLocations, id: \.self) { loc in
                                            Text(loc).tag(loc)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .tint(.appAccent)
                                }
                                
                                // Toggle: update location on scan
                                Toggle(isOn: $updateLocationOnScan) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Relocate on Scan")
                                            .font(.subheadline)
                                            .foregroundColor(.appPrimaryText)
                                        Text("Updates the item's location in the database to the selected location above.")
                                            .font(.caption2)
                                            .foregroundColor(.appSecondaryText)
                                    }
                                }
                                .tint(.appAccent)
                            }
                        }
                        .padding(.horizontal)
                        
                        // MARK: RFID Input Card
                        ReusableCardView {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Enter RFID Tag", systemImage: "wave.3.right.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.appPrimaryText)
                                
                                Text("Type or scan an RFID tag ID and press Return. The system will look it up in the database instantly.")
                                    .font(.caption)
                                    .foregroundColor(.appSecondaryText)
                                
                                HStack(spacing: 10) {
                                    TextField("e.g. RFID-1001, RFID-abc123…", text: $scanInput)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .autocorrectionDisabled()
                                        .textInputAutocapitalization(.characters)
                                        .onSubmit { lookupRFID() }
                                    
                                    Button(action: lookupRFID) {
                                        Group {
                                            if isScanning {
                                                ProgressView()
                                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                    .frame(width: 18, height: 18)
                                            } else {
                                                Image(systemName: "magnifyingglass")
                                            }
                                        }
                                        .frame(width: 44, height: 36)
                                        .background(Color.appAccent)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                    }
                                    .disabled(scanInput.trimmingCharacters(in: .whitespaces).isEmpty || isScanning)
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // MARK: Session Log
                        if !scanResults.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Session Log (\(scanResults.count))")
                                        .font(.headline)
                                        .foregroundColor(.appPrimaryText)
                                    Spacer()
                                    Button(action: { scanResults.removeAll() }) {
                                        Text("Clear")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    }
                                }
                                .padding(.horizontal)
                                
                                ForEach(scanResults.reversed()) { result in
                                    auditResultCard(result)
                                }
                            }
                        } else {
                            // Empty state
                            VStack(spacing: 12) {
                                Image(systemName: "wave.3.right.circle")
                                    .font(.system(size: 50))
                                    .foregroundColor(.appBorder)
                                Text("No scans yet")
                                    .font(.subheadline)
                                    .foregroundColor(.appSecondaryText)
                                Text("Enter an RFID tag above to locate items in the database.")
                                    .font(.caption)
                                    .foregroundColor(.appSecondaryText)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top)
                }
            }
            .navigationTitle("Audit Scanner")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                    .foregroundColor(CatalogTheme.primaryText)
                }
            }
            .task {
                await loadLocations()
            }
        }
    }
    
    // MARK: - Audit Result Card
    
    @ViewBuilder
    private func auditResultCard(_ result: AuditScanResult) -> some View {
        ReusableCardView {
            HStack(alignment: .top, spacing: 12) {
                // Status icon
                Image(systemName: result.statusIcon)
                    .font(.title2)
                    .foregroundColor(result.statusColor)
                    .frame(width: 36)
                
                VStack(alignment: .leading, spacing: 6) {
                    if let item = result.item {
                        // Found
                        HStack {
                            Text(item.productName)
                                .font(.subheadline.bold())
                                .foregroundColor(.appPrimaryText)
                            Spacer()
                            Text(item.status.rawValue)
                                .font(.caption2.bold())
                                .foregroundColor(result.statusColor)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(result.statusColor.opacity(0.15))
                                .cornerRadius(6)
                        }
                        
                        // RFID + Category
                        HStack(spacing: 8) {
                            Label(result.rfid, systemImage: "wave.3.right")
                                .font(.caption)
                                .foregroundColor(.appSecondaryText)
                            
                            Text("·")
                                .foregroundColor(.appBorder)
                            
                            Text(item.category)
                                .font(.caption)
                                .foregroundColor(.appSecondaryText)
                        }
                        
                        // Location
                        HStack(spacing: 4) {
                            Image(systemName: "mappin.circle.fill")
                                .font(.caption)
                                .foregroundColor(.appAccent)
                            if let updated = result.updatedLocation {
                                Text("\(item.location)  →  \(updated)")
                                    .font(.caption)
                                    .foregroundColor(.appAccent)
                                    .bold()
                            } else {
                                Text(item.location)
                                    .font(.caption)
                                    .foregroundColor(.appPrimaryText)
                            }
                        }
                        
                        // Batch + Serial
                        HStack(spacing: 8) {
                            Label("Batch: \(item.batchNo)", systemImage: "square.stack.3d.down.right")
                                .font(.caption2)
                                .foregroundColor(.appSecondaryText)
                            Text("·")
                                .foregroundColor(.appBorder)
                            Label("SN: \(item.serialId)", systemImage: "number")
                                .font(.caption2)
                                .foregroundColor(.appSecondaryText)
                        }
                        
                    } else {
                        // Not found
                        Text("RFID Not Found")
                            .font(.subheadline.bold())
                            .foregroundColor(.red)
                        Text(result.rfid)
                            .font(.caption)
                            .foregroundColor(.appSecondaryText)
                        Text("No item with this RFID tag exists in the database.")
                            .font(.caption2)
                            .foregroundColor(.red.opacity(0.8))
                    }
                    
                    // Timestamp
                    Text("Scanned at \(result.scannedAt.formatted(date: .omitted, time: .standard))")
                        .font(.caption2)
                        .foregroundColor(.appSecondaryText.opacity(0.7))
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Database Lookup
    
    private func lookupRFID() {
        let tag = scanInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        
        isScanning = true
        
        Task {
            do {
                let foundItem = try await DataService.shared.fetchInventoryItemByRFID(tag)
                var relocatedTo: String? = nil
                
                // If relocate-on-scan is enabled and item was found, update location
                if let item = foundItem, updateLocationOnScan, item.location != selectedLocation {
                    do {
                        try await DataService.shared.updateInventoryItemLocation(id: item.id, newLocation: selectedLocation)
                        relocatedTo = selectedLocation
                    } catch {
                        print("Failed to update location: \(error)")
                    }
                }
                
                let result = AuditScanResult(
                    scannedAt: Date(),
                    rfid: tag,
                    item: foundItem,
                    updatedLocation: relocatedTo
                )
                
                await MainActor.run {
                    scanResults.append(result)
                    scanInput = ""
                    isScanning = false
                }
                
            } catch {
                let result = AuditScanResult(
                    scannedAt: Date(),
                    rfid: tag,
                    item: nil,
                    updatedLocation: nil
                )
                await MainActor.run {
                    scanResults.append(result)
                    scanInput = ""
                    isScanning = false
                }
            }
        }
    }
    
    // MARK: - Load real DB locations
    
    private func loadLocations() async {
        do {
            let items = try await DataService.shared.fetchInventoryItems()
            let locs = Array(Set(items.map { $0.location })).filter { !$0.isEmpty }.sorted()
            if !locs.isEmpty {
                availableLocations = locs
                if !locs.contains(selectedLocation) {
                    selectedLocation = locs[0]
                }
            }
        } catch {
            print("Failed to load locations: \(error)")
        }
    }
}
