import SwiftUI
import PhotosUI

/// Sheet for Inventory Manager to perform a physical goods check for a vendor order and generate a GRN.
struct VendorGRNFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: TransfersViewModel

    let vendorOrder: VendorOrder
    let onGRNCreated: (String) -> Void

    @State private var quantityReceived: String = ""
    @State private var selectedCondition: GoodsReceivedNote.GRNCondition = .good
    @State private var notes: String = ""
    @State private var showSuccess = false
    @State private var generatedGRN: String = ""

    // Photo Proof
    @State private var photoItem: PhotosPickerItem? = nil
    @State private var proofImage: UIImage? = nil
    
    // SMS Composition
    @State private var showSMSComposer = false
    @State private var smsBody: String = ""

    private var orderedQuantity: Int {
        vendorOrder.quantity ?? 0
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
                    // Order info card
                    orderSummaryCard

                    // Physical check card
                    physicalCheckCard

                    // Notes
                    notesCard

                    // Photo Proof (only if damaged or partial)
                    if selectedCondition == .damaged || selectedCondition == .partial {
                        photoProofCard
                    }

                    // Submit
                    submitButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 40)
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Receive Vendor Goods")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }
            }
            .overlay {
                if showSuccess {
                    grnSuccessOverlay
                        .transition(.opacity)
                }
            }
            .onAppear {
                quantityReceived = "\(orderedQuantity)"
            }
            .sheet(isPresented: $showSMSComposer) {
                MessageComposerView(
                    recipients: [extractPhone(from: vendorOrder.vendor?.contactInfo, defaultPhone: "1234567890")],
                    body: smsBody
                ) { result in
                    // When the user dismisses the SMS view, close the GRN sheet as well.
                    onGRNCreated(generatedGRN)
                    dismiss()
                }
            }
        }
    }

    // MARK: - Sub-views

    private var orderSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Order Details", systemImage: "shippingbox")
                .headingStyle()

            HStack {
                Text("PO Number")
                    .font(.caption)
                    .foregroundColor(.appSecondaryText)
                Spacer()
                Text("PO-\(vendorOrder.id.uuidString.prefix(5).uppercased())")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundColor(.appAccent)
            }

            if let vendor = vendorOrder.vendor {
                HStack {
                    Text("Vendor")
                        .font(.caption)
                        .foregroundColor(.appSecondaryText)
                    Spacer()
                    Text(vendor.name)
                        .font(.caption.bold())
                        .foregroundColor(.appPrimaryText)
                }
            }

            HStack {
                Text("Ordered Qty")
                    .font(.caption)
                    .foregroundColor(.appSecondaryText)
                Spacer()
                Text("\(orderedQuantity) units")
                    .font(.caption.bold())
                    .foregroundColor(.appPrimaryText)
            }

            if let product = vendorOrder.product {
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
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 0.8))
    }

    private var physicalCheckCard: some View {
        VStack(spacing: 0) {
            Label("Physical Inspection", systemImage: "eye")
                .headingStyle()
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
        .background(Color(UIColor.secondarySystemGroupedBackground))
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
            Label("Inspection Notes", systemImage: "note.text")
                .headingStyle()
            TextEditor(text: $notes)
                .frame(minHeight: 80, maxHeight: 120)
                .font(.system(size: 14))
                .foregroundColor(.appPrimaryText)
                .padding(8)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .cornerRadius(10)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 0.8))
    }

    private var photoProofCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Photo Proof Required", systemImage: "camera")
                .headingStyle()
                .foregroundColor(Color.red)
            
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
                    .foregroundColor(Color.appAccent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .background(Color.appAccent.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.appAccent.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
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
        .background(Color(UIColor.secondarySystemGroupedBackground))
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
                        Image(systemName: "checkmark.seal.fill")
                        Text("Confirm Receipt & Generate GRN")
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
                    .cornerRadius(AppTheme.cardCornerRadius)
                Text("All received items were added to the Items tab with batch-linked RFID tags, and live stock has been updated.")
                    .font(.subheadline)
                    .foregroundColor(.appSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                
                Button {
                    if selectedCondition == .damaged || selectedCondition == .partial {
                        smsBody = buildVendorIssueMessage(
                            poNumber: "PO-\(vendorOrder.id.uuidString.prefix(5).uppercased())",
                            productName: vendorOrder.product?.name ?? "Product",
                            quantity: Int(quantityReceived) ?? orderedQuantity,
                            condition: selectedCondition.rawValue,
                            notes: notes
                        )
                        showSMSComposer = true
                    } else {
                        onGRNCreated(generatedGRN)
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.green)
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
            }
            .padding(32)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(AppTheme.cardCornerRadius)
            .shadow(radius: 30)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Actions

    private func submitGRN() async {
        let qty = Int(quantityReceived) ?? orderedQuantity
        if let grn = await viewModel.receiveVendorOrder(
            order: vendorOrder,
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
