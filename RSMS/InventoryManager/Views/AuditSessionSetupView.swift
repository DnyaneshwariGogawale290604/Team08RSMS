import SwiftUI

struct AuditSessionSetupView: View {
    @ObservedObject var viewModel: InventoryDashboardViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedLocation: String = ""
    @State private var isStarting = false
    
    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Audit Configuration").headingStyle()
                            .padding(.horizontal, 4)
                        
                        ReusableCardView {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Text("Location to Audit")
                                        .font(.subheadline)
                                        .foregroundColor(.appSecondaryText)
                                    Spacer()
                                    Picker("Location", selection: $selectedLocation) {
                                        ForEach(viewModel.locations, id: \.self) { loc in
                                            Text(loc).tag(loc)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                
                                detailDivider()
                                
                                Text("Starting an audit will fetch all items expected at this location and prepare for RFID scanning.")
                                    .font(.caption)
                                    .foregroundColor(.appSecondaryText)
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    Button(action: startAudit) {
                        HStack {
                            Spacer()
                            if isStarting {
                                ProgressView().tint(.white).padding(.trailing, 8)
                            }
                            Text("Start Audit Session")
                                .font(.headline)
                            Spacer()
                        }
                        .padding()
                        .background(selectedLocation.isEmpty || isStarting ? CatalogTheme.inactiveBadge : Color.appAccent)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    }
                    .disabled(selectedLocation.isEmpty || isStarting)
                    .padding(.horizontal, 20)
                }
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("New Audit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { presentationMode.wrappedValue.dismiss() } label: {
                    AppToolbarGlyph(systemImage: "xmark", backgroundColor: .appAccent)
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            if selectedLocation.isEmpty, let first = viewModel.locations.first {
                selectedLocation = first
            }
        }
    }

    private func detailDivider() -> some View {
        Divider().overlay(Color.black.opacity(0.08))
    }
    
    private func startAudit() {
        isStarting = true
        
        // Fetch all items at this location
        let expectedItems = viewModel.inventoryItems.filter { $0.location == selectedLocation }
        let expectedIds = expectedItems.map { $0.id }
        
        let session = AuditSession(
            location: selectedLocation,
            expectedItemIds: expectedIds
        )
        
        // Dismiss this setup and tell parent to open scanner with session
        NotificationCenter.default.post(
            name: NSNotification.Name("StartAuditSession"),
            object: nil,
            userInfo: ["session": session]
        )
        
        presentationMode.wrappedValue.dismiss()
    }
}
