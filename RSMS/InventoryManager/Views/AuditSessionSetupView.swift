import SwiftUI

struct AuditSessionSetupView: View {
    @ObservedObject var viewModel: InventoryDashboardViewModel
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedLocation: String = ""
    @State private var isStarting = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Audit Configuration").headingStyle()) {
                    Picker("Location to Audit", selection: $selectedLocation) {
                        ForEach(viewModel.locations, id: \.self) { loc in
                            Text(loc).tag(loc)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    Text("Starting an audit will fetch all items expected at this location and prepare for RFID scanning.")
                        .font(.caption)
                        .foregroundColor(.appSecondaryText)
                }
                
                Section {
                    Button(action: startAudit) {
                        HStack {
                            if isStarting {
                                ProgressView().padding(.trailing, 5)
                            }
                            Text("Start Audit Session")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white)
                    }
                    .listRowBackground(selectedLocation.isEmpty ? Color.gray : Color.appAccent)
                    .disabled(selectedLocation.isEmpty || isStarting)
                }
            }
            .navigationTitle("New Audit")
            .navigationBarItems(leading: Button("Cancel") {
                presentationMode.wrappedValue.dismiss()
            })
            .onAppear {
                if selectedLocation.isEmpty, let first = viewModel.locations.first {
                    selectedLocation = first
                }
            }
        }
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
