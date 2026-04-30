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
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // MARK: Order Summary
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Order Summary").headingStyle()
                            .padding(.horizontal, 4)
                        
                        ReusableCardView {
                            VStack(spacing: 0) {
                                detailRow(label: "Product", value: group.product?.name ?? "Unknown Product")
                                detailDivider()
                                detailRow(label: "Boutique", value: group.store?.name ?? "Unknown Boutique")
                                detailDivider()
                                
                                HStack {
                                    Text("Qty to Dispatch")
                                        .font(.subheadline)
                                        .foregroundColor(.appSecondaryText)
                                    Spacer()
                                    TextField("Units", text: $dispatchQuantityText)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.appPrimaryText)
                                        .multilineTextAlignment(.trailing)
                                        .keyboardType(.numberPad)
                                        .onChange(of: dispatchQuantityText) { newValue in
                                            dispatchQuantityText = newValue.filter { $0.isNumber }
                                        }
                                }
                                .padding(.vertical, 12)
                                
                                if group.requests.count > 1 {
                                    detailDivider()
                                    HStack(spacing: 6) {
                                        Image(systemName: "info.circle.fill")
                                            .font(.caption)
                                            .foregroundColor(.appAccent)
                                        Text("\(group.requests.count) requests merged · total \(group.totalQuantity) units")
                                            .font(.caption)
                                            .foregroundColor(.appSecondaryText)
                                    }
                                    .padding(.vertical, 8)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // MARK: Carrier & Tracking
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Carrier & Tracking").headingStyle()
                            .padding(.horizontal, 4)
                        
                        ReusableCardView {
                            VStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Carrier")
                                        .font(.caption.bold())
                                        .foregroundColor(.appSecondaryText)
                                    TextField("e.g. FedEx, DHL, Blue Dart", text: $carrier)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .padding(12)
                                        .background(Color.appBackground)
                                        .cornerRadius(10)
                                }
                                
                                Divider().overlay(Color.black.opacity(0.08))
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Tracking Number")
                                        .font(.caption.bold())
                                        .foregroundColor(.appSecondaryText)
                                    TextField("Enter number", text: $trackingNumber)
                                        .textFieldStyle(PlainTextFieldStyle())
                                        .padding(12)
                                        .background(Color.appBackground)
                                        .cornerRadius(10)
                                        .keyboardType(.asciiCapable)
                                }
                                
                                Divider().overlay(Color.black.opacity(0.08))
                                
                                DatePicker("Est. Delivery", selection: $estimatedDelivery, in: Date()..., displayedComponents: .date)
                                    .font(.subheadline)
                                    .foregroundColor(.appSecondaryText)
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // MARK: Notes
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes (Optional)").headingStyle()
                            .padding(.horizontal, 4)
                        
                        ReusableCardView {
                            TextEditor(text: $notes)
                                .frame(minHeight: 100)
                                .scrollContentBackground(.hidden)
                                .background(Color.appBackground)
                                .cornerRadius(10)
                                .padding(4)
                        }
                    }
                    .padding(.horizontal, 20)

                    // MARK: Submit
                    Button {
                        Task { await submitShipment() }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Label("Confirm & Generate ASN", systemImage: "shippingbox.fill")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(isFormValid && !viewModel.isLoading ? Color.appAccent : CatalogTheme.inactiveBadge)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    }
                    .disabled(!isFormValid || viewModel.isLoading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Shipment Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    AppToolbarGlyph(systemImage: "xmark", backgroundColor: .appAccent)
                }
                .buttonStyle(.plain)
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
        .onAppear {
            dispatchQuantityText = "\(group.totalQuantity)"
        }
    }

    private func detailRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.appSecondaryText)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(.appPrimaryText)
        }
        .padding(.vertical, 12)
    }
    
    private func detailDivider() -> some View {
        Divider()
            .overlay(Color.black.opacity(0.08))
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
                    .foregroundColor(Color.appAccent)
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
            .cornerRadius(AppTheme.cardCornerRadius)
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
