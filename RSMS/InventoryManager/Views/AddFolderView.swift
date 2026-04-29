import SwiftUI

public struct AddFolderView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var engine = InventoryEngine.shared
    @ObservedObject var viewModel: InventoryDashboardViewModel
    
    @State private var folderName: String = ""
    @State private var batchNo: String = "B-\(Int.random(in: 100...999))"
    @State private var location: String = ""
    @State private var itemCount: Int = 1
    @State private var errorMessage: String? = nil
    @State private var showSuccess = false
    
    public init(viewModel: InventoryDashboardViewModel) {
        self.viewModel = viewModel
        self._location = State(initialValue: viewModel.locations.first ?? "Warehouse")
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header illustration
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color.appAccent.opacity(0.12))
                                    .frame(width: 90, height: 90)
                                
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 40))
                                    .foregroundColor(.appAccent)
                            }
                            
                            Text("Create New Batch Category")
                                .font(.title3.bold())
                                .foregroundColor(.appPrimaryText)
                            
                            Text("Add a new product category (folder) with a batch of items that will appear in your inventory.")
                                .font(.subheadline)
                                .foregroundColor(.appSecondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                        }
                        .padding(.top, 20)
                        
                        // Form
                        VStack(spacing: 16) {
                            // Category Name
                            ReusableCardView {
                                VStack(alignment: .leading, spacing: 10) {
                                    Label("Category Name", systemImage: "folder.fill")
                                        .headingStyle()
                                    
                                    TextField("Category Name", text: $folderName)
                                        .padding(12)
                                        .background(Color.appBackground)
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.appBorder, lineWidth: 1)
                                        )
                                    
                                    if engine.inventory.map({ $0.category }).contains(folderName) && !folderName.isEmpty {
                                        HStack(spacing: 4) {
                                            Image(systemName: "info.circle.fill")
                                                .font(.caption2)
                                            Text("Category already exists — items will be added to it.")
                                                .font(.caption)
                                        }
                                        .foregroundColor(.orange)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            // Batch Number
                            ReusableCardView {
                                VStack(alignment: .leading, spacing: 10) {
                                    Label("Batch Number", systemImage: "number.circle.fill")
                                        .headingStyle()
                                    
                                    TextField("Batch identifier", text: $batchNo)
                                        .padding(12)
                                        .background(Color.appBackground)
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.appBorder, lineWidth: 1)
                                        )
                                }
                            }
                            .padding(.horizontal)
                            
                            // Location
                            ReusableCardView {
                                VStack(alignment: .leading, spacing: 10) {
                                    Label("Storage Location", systemImage: "mappin.circle.fill")
                                        .headingStyle()
                                    
                                    Picker("Location", selection: $location) {
                                        ForEach(viewModel.locations, id: \.self) { loc in
                                            Text(loc).tag(loc)
                                        }
                                    }
                                    .pickerStyle(MenuPickerStyle())
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.appBackground)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.appBorder, lineWidth: 1)
                                    )
                                }
                            }
                            .padding(.horizontal)
                            
                            // Item Count
                            ReusableCardView {
                                VStack(alignment: .leading, spacing: 10) {
                                    Label("Number of Items", systemImage: "shippingbox.fill")
                                        .headingStyle()
                                    
                                    TextField("0", value: $itemCount, format: .number)
                                        .keyboardType(.numberPad)
                                        .font(.title2.bold())
                                        .foregroundColor(.appPrimaryText)
                                        .padding()
                                        .background(Color.appBackground)
                                        .cornerRadius(10)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.appBorder, lineWidth: 1)
                                        )
                                    
                                    Text("Each item will get a unique RFID tag and serial number.")
                                        .font(.caption)
                                        .foregroundColor(.appSecondaryText)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Error
                        if let error = errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(error)
                                    .font(.subheadline)
                            }
                            .foregroundColor(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                        }
                        
                        // Success
                        if showSuccess {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("\(itemCount) items added to \"\(folderName)\"!")
                                    .font(.subheadline.bold())
                            }
                            .foregroundColor(.green)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        
                        // Removed Submit Button Section
                    }
                }
            }
            .navigationTitle("Add Folder")
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
                    Button { createFolder() } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(!folderName.isEmpty ? .primary : Color.gray)
                    }
                    .disabled(folderName.isEmpty)
                }
            }
        }
    }
    
    private func createFolder() {
        guard !folderName.isEmpty else {
            errorMessage = "Please enter a category name."
            return
        }
        
        guard !batchNo.isEmpty else {
            errorMessage = "Please enter a batch number."
            return
        }
        
        errorMessage = nil
        
        // Create N items with unique RFIDs and serial numbers
        for i in 0..<itemCount {
            let rfid = "RFID-\(batchNo)-\(String(format: "%03d", i + 1))"
            
            // Skip if RFID already exists
            if engine.inventory.contains(where: { $0.id == rfid }) {
                continue
            }
            
            let newItem = InventoryItem(
                id: rfid,
                serialId: "SN-\(Int.random(in: 1000...9999))",
                productId: UUID(),
                batchNo: batchNo,
                certificateId: nil,
                productName: folderName,
                category: folderName,
                location: location,
                status: .available
            )
            engine.inventory.insert(newItem, at: 0)
        }
        
        // Update stock levels
        engine.updateStockLevel(sku: folderName, location: location, quantityDelta: itemCount)
        
        withAnimation { showSuccess = true }
        
        // Auto-dismiss after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            presentationMode.wrappedValue.dismiss()
        }
    }
}
