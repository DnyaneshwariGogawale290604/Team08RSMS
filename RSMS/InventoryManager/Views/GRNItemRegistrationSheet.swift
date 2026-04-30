import SwiftUI

/// Shown after a GRN is generated. Lets the Inventory Manager register each received item
/// with a unique RFID tag. Each item insertion also increments warehouse_inventory stock.
struct GRNItemRegistrationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var viewModel: TransfersViewModel

    let vendorOrder: VendorOrder
    let quantityReceived: Int
    let grnNumber: String
    let onDone: () -> Void

    // Derived batch number from GRN (e.g. "GRN-XY1234" → "BATCH-XY1234")
    private var batchNumber: String {
        let suffix = grnNumber.replacingOccurrences(of: "GRN-", with: "")
        return "BATCH-\(suffix)"
    }

    // One draft entry per received item
    @State private var rfidTags: [String] = []
    @State private var isSubmitting = false
    @State private var savedCount = 0
    @State private var showDoneOverlay = false
    @State private var errorMessage: String?

    private var product: Product? { vendorOrder.product }
    private var productName: String { product?.name ?? "Unknown Product" }
    private var category: String { product?.category.isEmpty == true ? "General" : (product?.category ?? "General") }

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Header Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("GRN Details").headingStyle()
                            .padding(.horizontal, 4)
                        
                        ReusableCardView {
                            VStack(spacing: 0) {
                                detailRow(label: "GRN Number", value: grnNumber)
                                detailDivider()
                                detailRow(label: "Batch Number", value: batchNumber)
                                detailDivider()
                                detailRow(label: "Product", value: productName)
                                detailDivider()
                                detailRow(label: "Items to Register", value: "\(quantityReceived) units")
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // RFID rows
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("RFID Tags").headingStyle()
                            Spacer()
                            Button {
                                generateDefaultTags()
                            } label: {
                                Label("Auto-fill", systemImage: "wand.and.stars")
                                    .font(.caption.bold())
                                    .foregroundColor(.appAccent)
                            }
                        }
                        .padding(.horizontal, 4)
                        
                        ReusableCardView {
                            VStack(spacing: 0) {
                                ForEach(rfidTags.indices, id: \.self) { idx in
                                    VStack(spacing: 0) {
                                        HStack(spacing: 12) {
                                            Text("\(idx + 1)")
                                                .font(.caption2.bold())
                                                .foregroundColor(.white)
                                                .frame(width: 24, height: 24)
                                                .background(Color.appAccent)
                                                .clipShape(Circle())

                                            TextField("RFID Tag", text: $rfidTags[idx])
                                                .font(.system(size: 14, design: .monospaced))
                                                .foregroundColor(.appPrimaryText)
                                                .autocapitalization(.allCharacters)
                                                .disableAutocorrection(true)

                                            Button {
                                                rfidTags[idx] = generateSingleTag(index: idx)
                                            } label: {
                                                Image(systemName: "arrow.clockwise")
                                                    .font(.caption)
                                                    .foregroundColor(.appSecondaryText)
                                            }
                                        }
                                        .padding(.vertical, 12)

                                        if idx < rfidTags.count - 1 {
                                            detailDivider()
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    if let err = errorMessage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(err).font(.caption.bold())
                        }
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }

                    // Submit button
                    Button {
                        Task { await registerItems() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView().tint(.white)
                            } else {
                                Label("Register \(quantityReceived) Items & Update Stock", systemImage: "tag.fill")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(!isSubmitting && rfidTagsAreValid ? Color.appAccent : CatalogTheme.inactiveBadge)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 4)
                    }
                    .disabled(isSubmitting || !rfidTagsAreValid)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                }
                .padding(.vertical, 24)
            }
        }
        .navigationTitle("Register Items")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    onDone()
                    dismiss()
                } label: {
                    AppToolbarGlyph(systemImage: "xmark", backgroundColor: .appAccent)
                }
                .buttonStyle(.plain)
            }
        }
        .overlay {
            if showDoneOverlay {
                doneOverlay.transition(.opacity)
            }
        }
        .onAppear { generateDefaultTags() }
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
        Divider().overlay(Color.black.opacity(0.08))
    }

    // MARK: - Sub-views

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("GRN Details", systemImage: "doc.text.fill")
                .headingStyle()

            rowInfo(label: "GRN Number", value: grnNumber)
            rowInfo(label: "Batch Number", value: batchNumber)
            rowInfo(label: "Product", value: productName)
            rowInfo(label: "Items to Register", value: "\(quantityReceived) units")
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 0.8))
        .padding(.horizontal, 20)
    }

    private var rfidListCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("RFID Tags", systemImage: "tag.fill")
                    .headingStyle()
                Spacer()
                Button {
                    generateDefaultTags()
                } label: {
                    Label("Auto-fill", systemImage: "wand.and.stars")
                        .font(.caption.bold())
                        .foregroundColor(.appAccent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider().padding(.horizontal, 16)

            ForEach(rfidTags.indices, id: \.self) { idx in
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        // Index badge
                        Text("\(idx + 1)")
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .frame(width: 22, height: 22)
                            .background(Color.appAccent)
                            .clipShape(Circle())

                        TextField("RFID Tag", text: $rfidTags[idx])
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.appPrimaryText)
                            .autocapitalization(.allCharacters)
                            .disableAutocorrection(true)

                        // Regenerate single tag
                        Button {
                            rfidTags[idx] = generateSingleTag(index: idx)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                                .foregroundColor(.appSecondaryText)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    if idx < rfidTags.count - 1 {
                        Divider().padding(.horizontal, 16)
                    }
                }
            }
        }
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.appBorder, lineWidth: 0.8))
        .padding(.horizontal, 20)
    }

    private var submitButton: some View {
        Button {
            Task { await registerItems() }
        } label: {
            Group {
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "tag.fill")
                        Text("Register \(quantityReceived) Items & Update Stock")
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
                .fill(!isSubmitting && rfidTagsAreValid ? Color.green : Color.appBorder)
        )
        .disabled(isSubmitting || !rfidTagsAreValid)
        .padding(.horizontal, 20)
    }

    private var doneOverlay: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundColor(.green)
                Text("\(savedCount) Items Registered!")
                    .font(.title2.bold())
                    .foregroundColor(.appPrimaryText)
                Text("Stock levels have been updated in the warehouse.")
                    .font(.subheadline)
                    .foregroundColor(.appSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                Button {
                    onDone()
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
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(AppTheme.cardCornerRadius)
            .shadow(radius: 30)
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func rowInfo(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.appSecondaryText)
            Spacer()
            Text(value)
                .font(.caption.bold())
                .foregroundColor(.appPrimaryText)
                .multilineTextAlignment(.trailing)
        }
    }

    private var rfidTagsAreValid: Bool {
        let trimmed = rfidTags.map { $0.trimmingCharacters(in: .whitespaces) }
        guard trimmed.allSatisfy({ !$0.isEmpty }) else { return false }
        return Set(trimmed).count == trimmed.count // no duplicates
    }

    private func generateDefaultTags() {
        let suffix = grnNumber.replacingOccurrences(of: "GRN-", with: "")
        rfidTags = (0..<quantityReceived).map { i in
            "RFID-\(suffix)-\(String(format: "%03d", i + 1))"
        }
    }

    private func generateSingleTag(index: Int) -> String {
        let suffix = grnNumber.replacingOccurrences(of: "GRN-", with: "")
        let rand = Int.random(in: 100...999)
        return "RFID-\(suffix)-\(String(format: "%03d", index + 1))-\(rand)"
    }

    // MARK: - Registration Logic

    private func registerItems() async {
        errorMessage = nil
        isSubmitting = true
        defer { isSubmitting = false }

        guard let productId = vendorOrder.product?.id ?? vendorOrder.productId else {
            errorMessage = "Product not found on this order."
            return
        }

        var count = 0
        for (idx, tag) in rfidTags.enumerated() {
            let rfid = tag.trimmingCharacters(in: .whitespaces)
            guard !rfid.isEmpty else { continue }

            let item = InventoryItem(
                id: rfid,
                serialId: "SN-\(Int.random(in: 10000...99999))",
                productId: productId,
                batchNo: batchNumber,
                certificateId: nil,
                productName: productName,
                category: category,
                location: "Warehouse",
                status: .available
            )

            do {
                try await DataService.shared.insertInventoryItem(item: item)
                // Increment warehouse stock by 1 per registered item
                if let warehouseId = try? await viewModel.resolveWarehouseId() {
                    try? await WarehouseService.shared.incrementStock(
                        warehouseId: warehouseId,
                        productId: productId,
                        by: 1
                    )
                }
                count += 1
            } catch {
                // Log and continue — don't block the whole batch for one failure
                print("⚠️ Failed to register item \(idx + 1): \(error.localizedDescription)")
            }
        }

        savedCount = count
        NotificationCenter.default.post(name: .inventoryManagerDataDidChange, object: nil)
        withAnimation(.spring()) { showDoneOverlay = true }
    }
}
