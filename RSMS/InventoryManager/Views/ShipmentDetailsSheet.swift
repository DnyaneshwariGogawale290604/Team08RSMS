import SwiftUI

/// Sheet presented to Inventory Manager when they want to ship an approved request.
/// Collects carrier/tracking/ETA details and generates an ASN on submit.
struct ShipmentDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let request: ProductRequest
    let onShipped: (String) -> Void  // called with generated ASN number

    @StateObject private var viewModel = TransfersViewModel()
    @State private var carrier: String = ""
    @State private var trackingNumber: String = ""
    @State private var estimatedDelivery: Date = Date().addingTimeInterval(3 * 86400)
    @State private var notes: String = ""
    @State private var showSuccess = false
    @State private var generatedASN: String = ""
    @State private var showErrorAlert = false

    private var isFormValid: Bool {
        !carrier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !trackingNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {

                    // Request Summary Card
                    requestSummaryCard

                    // Shipment Details Card
                    shipmentDetailsCard

                    // Notes Card
                    notesCard

                    // Ship Button
                    shipButton

                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color.appBackground.ignoresSafeArea())
            .navigationTitle("Shipment Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.appAccent)
                }
            }
            .overlay {
                if showSuccess {
                    asnSuccessBanner
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .alert("Error Creating Shipment", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "An unknown error occurred.")
            }
        }
    }

    // MARK: - Sub-views

    private var requestSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Order Summary", systemImage: "doc.text")
                .font(.caption.weight(.semibold))
                .foregroundColor(.appSecondaryText)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(request.product?.name ?? "Unknown Product")
                        .font(.headline)
                        .foregroundColor(.appPrimaryText)
                    Text("From: \(request.store?.name ?? "Unknown Boutique")")
                        .font(.subheadline)
                        .foregroundColor(.appSecondaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(request.requestedQuantity)")
                        .font(.title2.bold())
                        .foregroundColor(.appAccent)
                    Text("units")
                        .font(.caption2.weight(.medium))
                        .foregroundColor(.appSecondaryText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.appAccent.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color.appCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 0.8))
    }

    private var shipmentDetailsCard: some View {
        VStack(spacing: 0) {
            Label("Carrier & Tracking", systemImage: "shippingbox")
                .font(.caption.weight(.semibold))
                .foregroundColor(.appSecondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)

            Divider().padding(.horizontal, 16)

            fieldRow(label: "Carrier") {
                TextField("e.g. FedEx, DHL, Blue Dart", text: $carrier)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimaryText)
            }

            Divider().padding(.horizontal, 16)

            fieldRow(label: "Tracking No.") {
                TextField("Enter tracking number", text: $trackingNumber)
                    .multilineTextAlignment(.trailing)
                    .foregroundColor(.appPrimaryText)
            }

            Divider().padding(.horizontal, 16)

            HStack {
                Text("Est. Delivery")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appSecondaryText)
                Spacer()
                DatePicker("", selection: $estimatedDelivery, in: Date()..., displayedComponents: .date)
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(Color.appCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 0.8))
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Notes (optional)", systemImage: "note.text")
                .font(.caption.weight(.semibold))
                .foregroundColor(.appSecondaryText)
            TextEditor(text: $notes)
                .frame(minHeight: 80, maxHeight: 120)
                .font(.system(size: 14))
                .foregroundColor(.appPrimaryText)
                .padding(8)
                .background(Color.appBackground)
                .cornerRadius(10)
        }
        .padding(16)
        .background(Color.appCard)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 0.8))
    }

    private var shipButton: some View {
        Button {
            Task { await submitShipment() }
        } label: {
            Group {
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "shippingbox.fill")
                        Text("Confirm & Generate ASN")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
        .background(
            RoundedRectangle(cornerRadius: 50)
                .fill(isFormValid && !viewModel.isLoading ? Color.appAccent : Color.appBorder)
        )
        .disabled(!isFormValid || viewModel.isLoading)
    }

    private var asnSuccessBanner: some View {
        VStack {
            VStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.green)
                Text("Shipment Created!")
                    .font(.headline)
                Text(generatedASN)
                    .font(.system(.title3, design: .monospaced).bold())
                    .foregroundColor(.appAccent)
                Text("ASN Number — share with boutique")
                    .font(.caption)
                    .foregroundColor(.appSecondaryText)
            }
            .padding(24)
            .background(Color.appCard)
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
        if let asn = await viewModel.shipRequest(
            request: request,
            carrier: carrier.trimmingCharacters(in: .whitespacesAndNewlines),
            trackingNumber: trackingNumber.trimmingCharacters(in: .whitespacesAndNewlines),
            estimatedDelivery: etaString,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        ) {
            generatedASN = asn
            withAnimation(.spring()) { showSuccess = true }
        } else if viewModel.errorMessage != nil {
            showErrorAlert = true
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func fieldRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.appSecondaryText)
                .frame(minWidth: 80, alignment: .leading)
            Spacer()
            content()
                .font(.system(size: 14))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
