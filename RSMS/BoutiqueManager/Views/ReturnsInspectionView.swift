// PATH: RSMS/BoutiqueManager/Views/ReturnsInspectionView.swift

import SwiftUI
import Supabase

struct ReturnsInspectionView: View {
    @StateObject private var viewModel = CustomerShippingViewModel()
    @Environment(\.dismiss) var dismiss
    @State private var selectedEntry: CustomerShippingViewModel.ReturnLogEntry?
    @State private var selectedCondition: String = "Good"
    @State private var resolution: String = "Restock"
    var body: some View {
        ZStack {
            BoutiqueTheme.offWhite.ignoresSafeArea()
            VStack(spacing: 0) {
                if viewModel.isLoading && viewModel.returnsQueue.isEmpty {
                    ProgressView().padding(40)
                } else if viewModel.returnsQueue.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.seal.fill").font(.system(size: 60)).foregroundStyle(Color.green.opacity(0.3))
                        Text("All Clear!").font(BrandFont.body(20, weight: .bold))
                        Text("No pending returns to inspect.").font(BrandFont.body(14)).foregroundStyle(Color.luxurySecondaryText)
                    }.padding(40)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.returnsQueue) { entry in
                                ReturnEntryRow(entry: entry) { self.selectedEntry = entry }
                            }
                        }.padding(16)
                    }.refreshable { if let brandId = try? await DataService.shared.resolveCurrentUserBrandIdOrThrow() { await viewModel.fetchReturnsQueue(for: brandId) } }
                }
            }
        }
        .navigationTitle("Returns Queue")
        .task { if let brandId = try? await DataService.shared.resolveCurrentUserBrandIdOrThrow() { await viewModel.fetchReturnsQueue(for: brandId) } }
        .sheet(item: $selectedEntry) { entry in
            InspectionModal(entry: entry, selectedCondition: $selectedCondition, resolution: $resolution, onPerform: { performAction(isResend: false) }, onResend: { performAction(isResend: true) })
        }
    }
    private func performAction(isResend: Bool) {
        Task {
            guard let brandId = try? await DataService.shared.resolveCurrentUserBrandIdOrThrow(), let userId = try? await SupabaseManager.shared.client.auth.session.user.id else { return }
            let success = isResend ? await viewModel.resendShipment(returnLogId: selectedEntry?.id ?? UUID(), inspectedBy: userId) : await viewModel.processReturn(returnLogId: selectedEntry?.id ?? UUID(), inspectedBy: userId, condition: selectedCondition, resolution: resolution)
            if success { await viewModel.fetchReturnsQueue(for: brandId); selectedEntry = nil }
        }
    }
}

struct ReturnEntryRow: View {
    let entry: CustomerShippingViewModel.ReturnLogEntry
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ORDER #\(entry.orderId.uuidString.prefix(8).uppercased())").font(.system(size: 10, weight: .bold, design: .monospaced)).foregroundStyle(Color.luxurySecondaryText)
                        Text(entry.productName ?? "Unknown Product").font(BrandFont.body(15, weight: .bold))
                    }
                    Spacer()
                    ConditionTag(condition: entry.condition)
                }
                Text("Reason: \(entry.returnReason)").font(BrandFont.body(13)).foregroundStyle(Color.luxurySecondaryText)
                HStack { Image(systemName: "clock"); Text("Requested \(entry.createdAt.formatted(date: .abbreviated, time: .omitted))"); Spacer(); Image(systemName: "chevron.right") }.font(.system(size: 11)).foregroundStyle(Color.luxurySecondaryText.opacity(0.7))
            }.padding(16).background(Color.white).cornerRadius(16).shadow(color: Color.black.opacity(0.03), radius: 8, y: 4)
        }.buttonStyle(.plain)
    }
}

struct InspectionModal: View {
    let entry: CustomerShippingViewModel.ReturnLogEntry
    @Binding var selectedCondition: String
    @Binding var resolution: String
    var onPerform: () -> Void
    var onResend: () -> Void
    @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) { Text("Inspect Item").font(BrandFont.body(20, weight: .bold)); Text(entry.productName ?? "Product").font(BrandFont.body(14)).foregroundStyle(Color.luxurySecondaryText) }.padding(.top, 20)
                VStack(alignment: .leading, spacing: 12) {
                    Text("CONDITION").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.luxurySecondaryText)
                    HStack(spacing: 12) { ForEach(["Good", "Damaged", "Incomplete"], id: \.self) { cond in Button { selectedCondition = cond } label: { Text(cond).font(.system(size: 13, weight: .medium)).padding(.vertical, 10).frame(maxWidth: .infinity).background(selectedCondition == cond ? BoutiqueTheme.primary : Color.luxurySurface).foregroundStyle(selectedCondition == cond ? .white : Color.luxuryPrimaryText).cornerRadius(12) } } }
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("RESOLUTION").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.luxurySecondaryText)
                    VStack(spacing: 12) {
                        ResolutionButton(title: "Restock to Inventory", icon: "arrow.up.bin.fill", isSelected: resolution == "Restock", color: .green) { resolution = "Restock" }
                        ResolutionButton(title: "Scrap / Damage Out", icon: "trash.fill", isSelected: resolution == "Scrap", color: .red) { resolution = "Scrap" }
                    }
                }
                Spacer()
                VStack(spacing: 12) {
                    Button(action: onPerform) { Text("Finalize Inspection").font(BrandFont.body(16, weight: .bold)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 16).background(BoutiqueTheme.primary).cornerRadius(16) }
                    Button(action: onResend) { Text("Resend New Shipment").font(BrandFont.body(14, weight: .semibold)).foregroundStyle(BoutiqueTheme.primary).padding(.vertical, 8) }
                }.padding(.bottom, 20)
            }.padding(24).navigationBarTitleDisplayMode(.inline).toolbar { ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } } }
        }
    }
}

struct ResolutionButton: View {
    let title: String; let icon: String; let isSelected: Bool; let color: Color; let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack { Image(systemName: icon).foregroundStyle(isSelected ? color : Color.luxurySecondaryText); Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(isSelected ? Color.luxuryPrimaryText : Color.luxurySecondaryText); Spacer(); if isSelected { Image(systemName: "checkmark.circle.fill").foregroundStyle(color) } }
            .padding().background(isSelected ? color.opacity(0.05) : Color.luxurySurface).overlay(RoundedRectangle(cornerRadius: 12).stroke(isSelected ? color.opacity(0.3) : Color.clear, lineWidth: 1)).cornerRadius(12)
        }.buttonStyle(.plain)
    }
}

private struct ConditionTag: View {
    let condition: String
    var body: some View {
        Text(condition.uppercased()).font(.system(size: 9, weight: .bold)).padding(.horizontal, 8).padding(.vertical, 4).background(color.opacity(0.1)).foregroundStyle(color).clipShape(Capsule())
    }
    private var color: Color {
        switch condition.lowercased() { case "good": return .green; case "damaged": return .red; case "incomplete": return .orange; default: return .gray }
    }
}
