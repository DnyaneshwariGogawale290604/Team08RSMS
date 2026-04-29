import SwiftUI

public struct BatchSerializationView: View {
    @Environment(\.presentationMode) var presentationMode
    public let transfer: Transfer
    
    @State private var itemInputs: [UUID: String] = [:]
    @State private var errorMessage: String? = nil
    
    private var totalExpectedQuantity: Int {
        transfer.items.reduce(0) { $0 + $1.quantity }
    }
    
    public init(transfer: Transfer) {
        self.transfer = transfer
    }
    
    public var body: some View {
        NavigationView {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        
                        // Header Details
                        ReusableCardView {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Batch Serialization")
                                    .headingStyle()
                                Text("Delivery involves **\(totalExpectedQuantity)** physical assets that need serialization mapping before integration into Vault inventory.")
                                    .font(.subheadline)
                                    .foregroundColor(.appSecondaryText)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        
                        // Error Alert Box
                        if let error = errorMessage {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.white)
                                Text(error)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                Spacer()
                            }
                            .padding()
                            .background(Color.red)
                            .cornerRadius(12)
                        }
                        
                        // Input Blocks for Each Item
                        ForEach(transfer.items) { item in
                            ReusableCardView {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack {
                                        Text(item.productName)
                                            .headingStyle()
                                        Spacer()
                                        let currentCount = extractSerials(from: itemInputs[item.id] ?? "").count
                                        Text("\(currentCount) / \(item.quantity)")
                                            .font(.subheadline)
                                            .foregroundColor(currentCount == item.quantity ? .green : .orange)
                                    }
                                    
                                    Text("Paste or type \(item.quantity) unique serial numbers below (comma/newline separated).")
                                        .font(.caption)
                                        .foregroundColor(.appSecondaryText)
                                    
                                    let binding = Binding<String>(
                                        get: { self.itemInputs[item.id] ?? "" },
                                        set: { self.itemInputs[item.id] = $0 }
                                    )
                                    
                                    TextEditor(text: binding)
                                        .frame(minHeight: 120)
                                        .padding(8)
                                        .background(Color.appBackground)
                                        .cornerRadius(8)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8)
                                                .stroke(Color.appBorder, lineWidth: 1)
                                        )
                                        .onChange(of: binding.wrappedValue) { _ in
                                            errorMessage = nil
                                        }
                                }
                            }
                        }
                        
                        // Removed Complete Ingestion Button
                    }
                    .padding()
                }
            }
            .navigationTitle("Ingest Shipment")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { presentationMode.wrappedValue.dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { submitBatch() } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isValidationSatisfied() ? .primary : Color.gray)
                    }
                    .disabled(!isValidationSatisfied())
                }
            }
        }
    }
    
    private func extractSerials(from text: String) -> [String] {
        return text
            .replacingOccurrences(of: ",", with: "\n")
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private func isValidationSatisfied() -> Bool {
        for item in transfer.items {
            let serials = extractSerials(from: itemInputs[item.id] ?? "")
            if serials.count != item.quantity {
                return false
            }
        }
        return true
    }
    
    private func getFlattenedChronologicalSerials() -> [String] {
        var rawSerials: [String] = []
        for item in transfer.items { // Preserve same chronology that engine receives logic parses physically 
            rawSerials.append(contentsOf: extractSerials(from: itemInputs[item.id] ?? ""))
        }
        return rawSerials
    }
    
    private func submitBatch() {
        let rawSerials = getFlattenedChronologicalSerials()
        
        do {
            try InventoryEngine.shared.receiveBatch(transferId: transfer.id, serials: rawSerials)
            presentationMode.wrappedValue.dismiss()
        } catch let error as SerializationError {
            self.errorMessage = error.localizedDescription
        } catch {
            self.errorMessage = "An unknown error occurred during ingestion."
        }
    }
}
