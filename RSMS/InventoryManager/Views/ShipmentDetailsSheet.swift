import SwiftUI

/// A grouped pick-list unit: one or more requests for the same product → same boutique.
struct PickListGroup: Identifiable {
    var id: UUID { requests.first!.id }          // stable – first request acts as primary
    let requests: [ProductRequest]               // all requests in this group

    var productId: UUID?    { requests.first?.productId }
    var storeId: UUID?      { requests.first?.storeId }
    var product: Product?   { requests.first?.product }
    var store: Store?       { requests.first?.store }

    /// Combined quantity across all requests in the group.
    var totalQuantity: Int  { requests.reduce(0) { $0 + $1.requestedQuantity } }
}

// MARK: - Sheet

/// Sheet presented to Inventory Manager when they want to ship an approved request (or group).
/// Collects carrier/tracking/ETA details and generates an ASN on submit.
struct ShipmentDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let group: PickListGroup
    let onShipped: (String) -> Void   // called with generated ASN number

    @StateObject private var viewModel = TransfersViewModel()
    @State private var carrier: String = ""
    @State private var trackingNumber: String = ""
    @State private var estimatedDelivery: Date = Date().addingTimeInterval(3 * 86400)
    @State private var dispatchQuantityText: String = ""
    @State private var notes: String = ""
    @State private var showErrorAlert = false
    @State private var generatedASN: String = ""
    @State private var showSuccess = false

    private var isFormValid: Bool {
        (Int(dispatchQuantityText) ?? 0) > 0 &&
        !carrier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !trackingNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    var body: some View {
        NavigationView {
            Form {
                // MARK: Order Summary
                Section {
                    LabeledContent("Product") {
                        Text(group.product?.name ?? "Unknown Product")
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Boutique") {
                        Text(group.store?.name ?? "Unknown Boutique")
                            .foregroundColor(.primary)
                            .multilineTextAlignment(.trailing)
                    }
                    LabeledContent("Qty to Dispatch") {
                        TextField("Units", text: $dispatchQuantityText)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.numberPad)
                            .onChange(of: dispatchQuantityText) { newValue in
                                dispatchQuantityText = newValue.filter { $0.isNumber }
                            }
                    }
                    if group.requests.count > 1 {
                        HStack(spacing: 6) {
                            Image(systemName: "info.circle")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("\(group.requests.count) requests merged · total \(group.totalQuantity) units")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } header: {
                    Text("Order Summary")
                }

                // MARK: Carrier & Tracking
                Section {
                    TextField("e.g. FedEx, DHL, Blue Dart", text: $carrier)
                        .autocorrectionDisabled()
                    TextField("Tracking number", text: $trackingNumber)
                        .autocorrectionDisabled()
                        .keyboardType(.asciiCapable)
                    DatePicker("Est. Delivery", selection: $estimatedDelivery,
                               in: Date()..., displayedComponents: .date)
                } header: {
                    Text("Carrier & Tracking")
                }

                // MARK: Notes
                Section {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                } header: {
                    Text("Notes (Optional)")
                }

                // MARK: Submit
                Section {
                    Button {
                        Task { await submitShipment() }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                            } else {
                                Label("Confirm & Generate ASN", systemImage: "shippingbox.fill")
                                    .fontWeight(.semibold)
                            }
                            Spacer()
                        }
                    }
                    .foregroundColor(isFormValid && !viewModel.isLoading ? .green : .secondary)
                    .disabled(!isFormValid || viewModel.isLoading)
                }
            }
            .navigationTitle("Shipment Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .overlay {
                if showSuccess {
                    asnSuccessBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .alert("Error Creating Shipment", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred.")
            }
        }
        .onAppear {
            dispatchQuantityText = "\(group.totalQuantity)"
        }
    }

    // MARK: - Success Banner

    private var asnSuccessBanner: some View {
        VStack {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                Text("Shipment Created!")
                    .font(.headline)
                Text(generatedASN)
                    .font(.system(.title3, design: .monospaced).bold())
                    .foregroundColor(.accentColor)
                Text("ASN Number — share with boutique")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Tap anywhere to continue")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
            .padding(28)
            .background(.regularMaterial)
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(.horizontal, 32)
            Spacer()
        }
        .padding(.top, 60)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.4).ignoresSafeArea())
        .onTapGesture {
            showSuccess = false
            onShipped(generatedASN)
            dismiss()
        }
    }

    // MARK: - Actions

    private func submitShipment() async {
        let etaString = dateFormatter.string(from: estimatedDelivery)
        let finalQty = Int(dispatchQuantityText) ?? group.totalQuantity
        let primaryRequest = group.requests[0]

        if let asn = await viewModel.shipRequest(
            request: primaryRequest,
            quantity: finalQty,
            carrier: carrier.trimmingCharacters(in: .whitespacesAndNewlines),
            trackingNumber: trackingNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            estimatedDelivery: etaString,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        ) {
            for req in group.requests.dropFirst() {
                _ = await viewModel.shipRequest(
                    request: req,
                    quantity: req.requestedQuantity,
                    carrier: carrier.trimmingCharacters(in: .whitespacesAndNewlines),
                    trackingNumber: trackingNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                    estimatedDelivery: etaString,
                    notes: "Merged with primary shipment \(asn)"
                )
            }
            generatedASN = asn
            withAnimation(.spring()) { showSuccess = true }
        } else if viewModel.errorMessage != nil {
            showErrorAlert = true
        }
    }
}
