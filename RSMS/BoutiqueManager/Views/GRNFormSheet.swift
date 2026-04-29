import SwiftUI
import PhotosUI

/// Sheet for Boutique Manager to perform a physical goods check and generate a GRN.
struct GRNFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: BoutiqueShipmentViewModel

    let shipment: Shipment
    let onGRNCreated: (String) -> Void

    @State private var quantityReceived: String = ""
    @State private var selectedCondition: GoodsReceivedNote.GRNCondition = .good
    @State private var notes: String = ""
    @State private var showSuccess = false
    @State private var generatedGRN: String = ""
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var proofImage: UIImage? = nil

    private var requestedQuantity: Int {
        shipment.request?.requestedQuantity ?? 0
    }

    private var isFormValid: Bool {
        let qty = Int(quantityReceived) ?? 0
        let hasValidQuantity = qty > 0
        let requiresProof = selectedCondition == .damaged || selectedCondition == .partial
        if requiresProof {
            return hasValidQuantity && proofImage != nil
        }
        return hasValidQuantity
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // Shipment info card
                    shipmentSummaryCard

                    // Physical check card
                    physicalCheckCard

                    // Notes
                    notesCard

                    // Photo Proof (only if damaged or partial)
                    if selectedCondition == .damaged || selectedCondition == .partial {
                        photoProofCard
                    }

                    // Error Message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(BoutiqueTheme.error)
                            .cornerRadius(10)
                    }

                    // Submit
                    submitButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(BoutiqueTheme.background.ignoresSafeArea())
            .navigationTitle("Receive Goods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .foregroundColor(.appAccent)
                }
            }
            .overlay {
                if showSuccess {
                    grnSuccessOverlay
                        .transition(.opacity)
                }
            }
            .onAppear {
                quantityReceived = "\(requestedQuantity)"
            }
        }
    }

    // MARK: - Sub-views

    private var shipmentSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 18))
                    .foregroundColor(BoutiqueTheme.primary)
                Text("Shipment Details")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(CatalogTheme.primaryText)
            }

            if let asn = shipment.asnNumber {
                HStack {
                    Text("ASN")
                        .font(.caption)
                        .foregroundColor(.appSecondaryText)
                    Spacer()
                    Text(asn)
                        .font(.system(.caption, design: .monospaced).bold())
                        .foregroundColor(.appAccent)
                }
            }

            if let carrier = shipment.carrier {
                HStack {
                    Text("Carrier")
                        .font(.caption)
                        .foregroundColor(.appSecondaryText)
                    Spacer()
                    Text(carrier)
                        .font(.caption.bold())
                        .foregroundColor(.appPrimaryText)
                }
            }

            HStack {
                Text("Ordered Qty")
                    .font(.caption)
                    .foregroundColor(.appSecondaryText)
                Spacer()
                Text("\(requestedQuantity) units")
                    .font(.caption.bold())
                    .foregroundColor(.appPrimaryText)
            }

            if let product = shipment.request?.product {
                HStack {
                    Text("Product")
                        .font(.caption)
                        .foregroundColor(.appSecondaryText)
                    Spacer()
                    Text(product.name)
                        .font(.caption.bold())
                        .foregroundColor(.appPrimaryText)
                }
            }
        }
        .padding(16)
        .background(BoutiqueTheme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 0.8))
    }

    private var physicalCheckCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "eye")
                    .font(.system(size: 18))
                    .foregroundColor(BoutiqueTheme.primary)
                Text("Physical Inspection")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(CatalogTheme.primaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 16)

            // Quantity received
            HStack {
                Text("Qty Received")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appSecondaryText)
                Spacer()
                TextField("Enter quantity", text: $quantityReceived)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.appPrimaryText)
                    .frame(width: 80)
#if canImport(UIKit)
                    .keyboardType(.numberPad)
#endif
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().padding(.horizontal, 16)

            // Condition
            VStack(alignment: .leading, spacing: 12) {
                Text("Condition")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.appSecondaryText)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                HStack(spacing: 10) {
                    ForEach(GoodsReceivedNote.GRNCondition.allCases, id: \.self) { cond in
                        conditionButton(cond)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
        }
        .background(BoutiqueTheme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 0.8))
    }

    private func conditionButton(_ condition: GoodsReceivedNote.GRNCondition) -> some View {
        let isSelected = selectedCondition == condition
        let (color, _): (Color, String) = {
            switch condition {
            case .good: return (.green, "")
            case .damaged: return (.red, "")
            case .partial: return (.orange, "")
            }
        }()

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedCondition = condition }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: condition.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isSelected ? .white : color)
                Text(condition.displayName)
                    .font(.caption2.bold())
                    .foregroundColor(isSelected ? .white : color)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? color : color.opacity(0.1))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(color, lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "note.text")
                    .font(.system(size: 18))
                    .foregroundColor(BoutiqueTheme.primary)
                Text("Inspection Notes")
                    .font(.system(size: 18, weight: .bold, design: .serif))
                    .foregroundColor(CatalogTheme.primaryText)
            }
            TextEditor(text: $notes)
                .frame(minHeight: 80, maxHeight: 120)
                .font(.system(size: 14))
                .foregroundColor(.appPrimaryText)
                .padding(8)
                .background(BoutiqueTheme.background)
                .cornerRadius(10)
        }
        .padding(16)
        .background(BoutiqueTheme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 0.8))
    }

    private var photoProofCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Photo Proof Required", systemImage: "camera")
                .font(.caption.weight(.semibold))
                .foregroundColor(BoutiqueTheme.error)
            
            Text("Please attach a clear photo showing the damage or issue.")
                .font(.caption)
                .foregroundColor(.appSecondaryText)
            
            if let img = proofImage {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 150)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    Button {
                        proofImage = nil
                        photoItem = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(8)
                }
            } else {
                PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.plus")
                            .font(.title)
                        Text("Add Photo Proof")
                            .font(.subheadline.bold())
                    }
                    .foregroundColor(BoutiqueTheme.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .background(BoutiqueTheme.primary.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(BoutiqueTheme.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                    )
                }
                .onChange(of: photoItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            proofImage = uiImage
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(BoutiqueTheme.card)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 0.8))
    }

    private var submitButton: some View {
        Button {
            Task { await submitGRN() }
        } label: {
            Group {
                if viewModel.isLoading {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: selectedCondition == .good ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        Text(selectedCondition == .good ? "Confirm Receipt & Generate GRN" : "Report Issue & Generate GRN")
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
                .fill(isFormValid && !viewModel.isLoading ? Color.green : Color.appBorder)
        )
        .disabled(!isFormValid || viewModel.isLoading)
    }

    private var grnSuccessOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.green)
                Text("GRN Generated!")
                    .font(.title2.bold())
                    .foregroundColor(.appPrimaryText)
                Text(generatedGRN)
                    .font(.system(.title3, design: .monospaced).bold())
                    .foregroundColor(.appAccent)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.appAccent.opacity(0.1))
                    .cornerRadius(12)
                Text("Both Inventory & Boutique can now see this GRN.")
                    .font(.subheadline)
                    .foregroundColor(.appSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                Button {
                    onGRNCreated(generatedGRN)
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(Color.green)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }
            .padding(32)
            .background(BoutiqueTheme.card)
            .cornerRadius(24)
            .shadow(radius: 30)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Actions

    private func submitGRN() async {
        // Clear any previous error before submitting
        viewModel.errorMessage = nil
        
        let qty = Int(quantityReceived) ?? requestedQuantity
        if let grn = await viewModel.receiveGoods(
            shipment: shipment,
            quantityReceived: qty,
            condition: selectedCondition,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            proofImage: proofImage
        ) {
            generatedGRN = grn
            withAnimation(.spring()) { showSuccess = true }
        }
    }
}
