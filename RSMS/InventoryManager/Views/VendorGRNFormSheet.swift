import SwiftUI

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

    private var orderedQuantity: Int {
        vendorOrder.quantity ?? 0
    }

    private var isFormValid: Bool {
        let qty = Int(quantityReceived) ?? 0
        return qty > 0
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
                    Button("Cancel") { dismiss() }
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
                quantityReceived = "\(orderedQuantity)"
            }
        }
    }

    // MARK: - Sub-views

    private var orderSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Order Details", systemImage: "shippingbox")
                .font(.caption.weight(.semibold))
                .foregroundColor(.appSecondaryText)

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
                .font(.caption.weight(.semibold))
                .foregroundColor(.appSecondaryText)
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
                .font(.caption.weight(.semibold))
                .foregroundColor(.appSecondaryText)
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
                    .cornerRadius(12)
                Text("Inventory has been updated successfully.")
                    .font(.subheadline)
                    .foregroundColor(.appSecondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
                Button("Done") {
                    onGRNCreated(generatedGRN)
                    dismiss()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 40)
                .padding(.vertical, 14)
                .background(Color.green)
                .clipShape(Capsule())
                .padding(.top, 8)
            }
            .padding(32)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(24)
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
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        ) {
            generatedGRN = grn
            withAnimation(.spring()) { showSuccess = true }
        }
    }
}
