import SwiftUI

public struct RFIDScannerView: View {
    @Environment(\.presentationMode) var presentationMode
    
    // Core Data States
    @State private var selectedLocation: String = "Main Vault"
    @State private var scanInput: String = ""
    
    // Log Tracking State
    @State private var scannedLogs: [ScanLog] = []
    
    // Mock configurable locations
    let availableLocations = ["Main Vault", "Showroom Floor", "Paris Boutique", "Tokyo Boutique", "New York Store"]
    
    // Internal struct for tracking log history in this session
    struct ScanLog: Identifiable {
        let id = UUID()
        let timestamp: Date
        let tagContext: String
        let isSuccess: Bool
    }
    
    public init() {}
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    
                    // Location Configuration Header
                    ReusableCardView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Scanner Configuration")
                                .font(.headline)
                                .foregroundColor(.appPrimaryText)
                            
                            HStack {
                                Text("Destination Location")
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
                        }
                    }
                    
                    // Wand Input Block
                    ReusableCardView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Continuous RFID Capture")
                                .font(.headline)
                                .foregroundColor(.appPrimaryText)
                            
                            Text("Connect your hardware scanner to automatically ingest active location maps in real-time. Hit Return after each tag.")
                                .font(.caption)
                                .foregroundColor(.appSecondaryText)
                            
                            TextField("Scan RFID Tag here...", text: $scanInput)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onSubmit {
                                    processExternalScan()
                                }
                        }
                    }
                    
                    // Live Session Logs
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Session Logs (\(scannedLogs.count))")
                            .font(.headline)
                            .foregroundColor(.appPrimaryText)
                            .padding(.horizontal)
                        
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(scannedLogs.reversed()) { log in
                                    HStack {
                                        Image(systemName: log.isSuccess ? "checkmark.circle.fill" : "xmark.octagon.fill")
                                            .foregroundColor(log.isSuccess ? .green : .red)
                                        
                                        VStack(alignment: .leading) {
                                            Text(log.tagContext)
                                                .font(.subheadline.bold())
                                                .foregroundColor(.appPrimaryText)
                                            Text(log.timestamp.formatted(date: .omitted, time: .standard))
                                                .font(.caption2)
                                                .foregroundColor(.appSecondaryText)
                                        }
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.appBorder.opacity(0.1))
                                    .cornerRadius(8)
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding(.top)
            }
            .navigationTitle("Audit Scanner")
            .navigationBarItems(trailing: Button("Done") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
    
    private func processExternalScan() {
        let tag = scanInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !tag.isEmpty else { return }
        
        do {
            let processedItem = try InventoryEngine.shared.scanAndLogItem(rfid: tag, newLocation: selectedLocation)
            
            let successLog = ScanLog(
                timestamp: processedItem.timestamp,
                tagContext: "Logged RFID \(processedItem.id) (\(processedItem.serialId)) -> \(selectedLocation)",
                isSuccess: true
            )
            scannedLogs.append(successLog)
            
        } catch let error as SerializationError {
            let errorLog = ScanLog(
                timestamp: Date(),
                tagContext: error.localizedDescription,
                isSuccess: false
            )
            scannedLogs.append(errorLog)
        } catch {
            let errorLog = ScanLog(
                timestamp: Date(),
                tagContext: "Unknown Processing Error on tag \(tag)",
                isSuccess: false
            )
            scannedLogs.append(errorLog)
        }
        
        // Wipe wand string automatically making space for next laser trigger
        scanInput = ""
    }
}
