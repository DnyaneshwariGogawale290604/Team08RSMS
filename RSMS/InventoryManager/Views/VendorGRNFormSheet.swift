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
        ZStack {
            CatalogTheme.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Order info card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Order Details").headingStyle()
                            .padding(.horizontal, 4)
                        
                        ReusableCardView {
                            VStack(spacing: 0) {
                                detailRow(label: "PO Number", value: "PO-\(vendorOrder.id.uuidString.prefix(5).uppercased())", valueColor: CatalogTheme.primary)
                                
                                if let vendor = vendorOrder.vendor {
                                    detailDivider()
                                    detailRow(label: "Vendor", value: vendor.name)
                                }
                                
                                detailDivider()
                                detailRow(label: "Ordered Qty", value: "\(orderedQuantity) units")
                                
                                if let product = vendorOrder.product {
                                    detailDivider()
                                    detailRow(label: "Product", value: product.name)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // Physical check card
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Physical Inspection").headingStyle()
                            .padding(.horizontal, 4)
                        
                        ReusableCardView {
                            VStack(spacing: 0) {
                                HStack {
                                    Text("Qty Received")
                                        .font(.subheadline)
                                        .foregroundColor(CatalogTheme.secondaryText)
                                    Spacer()
                                    TextField("Enter quantity", text: $quantityReceived)
                                        .font(.subheadline.bold())
                                        .foregroundColor(CatalogTheme.primaryText)
                                        .multilineTextAlignment(.trailing)
                                        .keyboardType(.numberPad)
                                        .frame(width: 100)
                                }
                                .padding(.vertical, 12)
                                
                                detailDivider()
                                
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Condition")
                                        .font(.caption.bold())
                                        .foregroundColor(CatalogTheme.secondaryText)
                                        .padding(.top, 8)

                                    HStack(spacing: 12) {
                                        ForEach(GoodsReceivedNote.GRNCondition.allCases, id: \.self) { cond in
                                            conditionButton(cond)
                                        }
                                    }
                                    .padding(.bottom, 12)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // Notes
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Inspection Notes").headingStyle()
                            .padding(.horizontal, 4)
                        
                        ReusableCardView {
                            TextEditor(text: $notes)
                                .frame(minHeight: 100)
                                .scrollContentBackground(.hidden)
                                .background(CatalogTheme.background)
                                .cornerRadius(10)
                                .padding(4)
                        }
                    }
                    .padding(.horizontal, 20)

                    // Photo Proof
                    if selectedCondition == .damaged || selectedCondition == .partial {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Photo Proof Required").headingStyle()
                                .foregroundColor(.red)
                                .padding(.horizontal, 4)
                            
                            ReusableCardView {
                                VStack(spacing: 16) {
                                    Text("Please attach a clear photo showing the damage or issue.")
                                        .font(.caption)
                                        .foregroundColor(CatalogTheme.secondaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    
                                    if let img = proofImage {
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(height: 180)
                                                .frame(maxWidth: .infinity)
                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                            
                                            Button {
                                                proofImage = nil
                                                photoItem = nil
                                            } label: {
                                                AppToolbarGlyph(systemImage: "trash", backgroundColor: .red)
                                            }
                                            .padding(12)
                                        }
                                    } else {
                                        PhotosPicker(selection: $photoItem, matching: .images) {
                                            VStack(spacing: 8) {
                                                Image(systemName: "photo.badge.plus")
                                                    .font(.title2)
                                                Text("Add Photo Proof")
                                                    .font(.subheadline.bold())
                                            }
                                            .foregroundColor(CatalogTheme.primary)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 120)
                                            .background(CatalogTheme.primary.opacity(0.12))
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(CatalogTheme.primary.opacity(0.2), style: StrokeStyle(lineWidth: 1, dash: [4]))
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
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Submit
                    Button {
                        Task { await submitGRN() }
                    } label: {
                        HStack {
                            Spacer()
                            if viewModel.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Label("Confirm Receipt & Generate GRN", systemImage: "checkmark.seal.fill")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(isFormValid && !viewModel.isLoading ? CatalogTheme.primary : CatalogTheme.inactiveBadge)
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
        .navigationTitle("Receive Vendor Goods")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button { dismiss() } label: {
                    AppToolbarGlyph(systemImage: "xmark", backgroundColor: CatalogTheme.primary)
                }
                .buttonStyle(.plain)
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
                onGRNCreated(generatedGRN)
                dismiss()
            }
        }
    }

    private func detailRow(label: String, value: String, valueColor: Color = CatalogTheme.primaryText) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(CatalogTheme.secondaryText)
            Spacer()
            Text(value)
                .font(.subheadline.bold())
                .foregroundColor(valueColor)
        }
        .padding(.vertical, 12)
    }
    
    private func detailDivider() -> some View {
        Divider().overlay(Color.black.opacity(0.08))
    }

    // MARK: - Sub-views

    private var orderSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Order Details", systemImage: "shippingbox")
                .headingStyle()

            HStack {
                Text("PO Number")
                    .font(.caption)
                    .foregroundColor(CatalogTheme.secondaryText)
                Spacer()
                Text("PO-\(vendorOrder.id.uuidString.prefix(5).uppercased())")
                    .font(.system(.caption, design: .monospaced).bold())
                    .foregroundColor(CatalogTheme.primary)
            }

            if let vendor = vendorOrder.vendor {
                HStack {
                    Text("Vendor")
                        .font(.caption)
                        .foregroundColor(CatalogTheme.secondaryText)
                    Spacer()
                    Text(vendor.name)
                        .font(.caption.bold())
                        .foregroundColor(CatalogTheme.primaryText)
                }
            }

            HStack {
                Text("Ordered Qty")
                    .font(.caption)
                    .foregroundColor(CatalogTheme.secondaryText)
                Spacer()
                Text("\(orderedQuantity) units")
                    .font(.caption.bold())
                    .foregroundColor(CatalogTheme.primaryText)
            }

            if let product = vendorOrder.product {
                HStack {
                    Text("Product")
                        .font(.caption)
                        .foregroundColor(CatalogTheme.secondaryText)
                    Spacer()
                    Text(product.name)
                        .font(.caption.bold())
                        .foregroundColor(CatalogTheme.primaryText)
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CatalogTheme.divider, lineWidth: 0.8))
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
                    .foregroundColor(CatalogTheme.secondaryText)
                Spacer()
                TextField("Enter quantity", text: $quantityReceived)
                    .multilineTextAlignment(.trailing)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(CatalogTheme.primaryText)
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
                    .foregroundColor(CatalogTheme.secondaryText)
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
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CatalogTheme.divider, lineWidth: 0.8))
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
                .foregroundColor(CatalogTheme.primaryText)
                .padding(8)
                .background(Color(UIColor.tertiarySystemGroupedBackground))
                .cornerRadius(10)
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CatalogTheme.divider, lineWidth: 0.8))
    }

    private var photoProofCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Photo Proof Required", systemImage: "camera")
                .headingStyle()
                .foregroundColor(Color.red)
            
            Text("Please attach a clear photo showing the damage or issue.")
                .font(.caption)
                .foregroundColor(CatalogTheme.secondaryText)
            
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
                    .foregroundColor(CatalogTheme.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .background(CatalogTheme.primary.opacity(0.1))
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(CatalogTheme.primary.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
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
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(CatalogTheme.divider, lineWidth: 0.8))
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
                .fill(isFormValid && !viewModel.isLoading ? Color.green : CatalogTheme.divider)
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
                    .foregroundColor(CatalogTheme.primaryText)
                Text(generatedGRN)
                    .font(.system(.title3, design: .monospaced).bold())
                    .foregroundColor(CatalogTheme.primary)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(CatalogTheme.primary.opacity(0.1))
                    .cornerRadius(AppTheme.cardCornerRadius)
                Text("All received items were added to the Items tab with batch-linked RFID tags, and live stock has been updated.")
                    .font(.subheadline)
                    .foregroundColor(CatalogTheme.secondaryText)
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
