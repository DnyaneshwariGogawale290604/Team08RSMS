import SwiftUI

struct BillingView: View {
    @ObservedObject var vm: AssociateSalesViewModel
    @EnvironmentObject var orderStore: SharedOrderStore
    @Environment(\.dismiss) var dismiss
    @State private var showDraftSavedToast = false
    let appointmentId: UUID?
    let maxLegs: Int      // from gateway config
    let maxSplits: Int    // from gateway config

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandOffWhite.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.lg) {
                        orderSummarySection
                        paymentLegsSection
                        validationSection
                        gatewayStatusSection
                    }
                    .padding(.vertical, Spacing.lg)
                }

                if vm.isLoading {
                    Color.black.opacity(0.05).ignoresSafeArea()
                }

                if showDraftSavedToast {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(hex: "#4A7C59"))
                                .font(.system(size: 16))
                            Text("Billing plan saved")
                                .font(BrandFont.body(13, weight: .medium))
                                .foregroundStyle(Color.brandWarmBlack)
                            Spacer()
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.lg)
                                .fill(Color.brandLinen)
                                .shadow(color: Color.brandWarmBlack.opacity(0.12),
                                        radius: 12, y: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.lg)
                                .stroke(Color(hex: "#4A7C59").opacity(0.3),
                                        lineWidth: 1)
                        )
                        .padding(.horizontal, Spacing.md)
                        .padding(.bottom, Spacing.lg)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75),
                               value: showDraftSavedToast)
                    .zIndex(10)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("BILLING & PAYMENT")
                        .font(.system(size: 13, weight: .semibold))
                        .kerning(2)
                        .foregroundStyle(Color.brandWarmBlack)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.brandWarmGrey)
                }
            }
            .safeAreaInset(edge: .bottom) {
                actionButtons
            }
            .task {
                await vm.fetchPaymentConfig()
                
                if let order = vm.currentOrder {
                    // 1. If we have a current order, fetch by order ID
                    await vm.fetchOrderPaymentSummary(salesOrderId: order.id.uuidString)
                } else if let apptId = appointmentId {
                    // 2. If no order but we have an appointment, try to fetch by appointment ID
                    await vm.fetchOrderPaymentSummary(appointmentId: apptId.uuidString)
                }
                
                // If after fetching we still have no legs (fresh case), initialize defaults
                if vm.billingLegs.isEmpty {
                    vm.initializeBillingLegs(maxLegs: maxLegs, maxSplits: maxSplits)
                }
            }
            .onDisappear {
                // Auto-save draft if legs are configured but not yet saved to DB
                let hasNewLegs = vm.billingLegs.contains { $0.isNew }
                if hasNewLegs && vm.currentOrder != nil {
                    Task {
                        await vm.saveBillingDraft(
                            appointmentId: appointmentId
                        )
                    }
                }
            }
        }
    }

    // MARK: - Sections

    private var orderSummarySection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(title: "Order Summary")
            
            VStack(spacing: 0) {
                ForEach(vm.cartItems) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.product.name)
                                .font(BrandFont.body(14, weight: .medium))
                                .foregroundStyle(Color.brandWarmBlack)
                            Text("₹\(Int(item.product.price)) × \(item.quantity)")
                                .font(BrandFont.body(12))
                                .foregroundStyle(Color.brandWarmGrey)
                        }
                        Spacer()
                        Text("₹\(Int(item.lineTotal))")
                            .font(BrandFont.body(14, weight: .semibold))
                            .foregroundStyle(Color.brandWarmBlack)
                    }
                    .padding(Spacing.md)
                    
                    if item.id != vm.cartItems.last?.id {
                        BrandDivider().padding(.leading, Spacing.md)
                    }
                }
                
                BrandDivider()
                
                HStack {
                    Text("Total Amount")
                        .font(BrandFont.body(15, weight: .bold))
                        .foregroundStyle(Color.brandWarmBlack)
                    Spacer()
                    Text("₹\(Int(vm.cartTotal))")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(Color.brandWarmBlack)
                }
                .padding(Spacing.md)
                .background(Color.brandLinen.opacity(0.5))
            }
            .background(Color.brandLinen)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.brandPebble, lineWidth: 0.5))
            .padding(.horizontal, Spacing.md)
        }
    }

    private var paymentLegsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(title: "Payment Legs")
            
            ForEach(vm.billingLegs.indices, id: \.self) { legIdx in
                legCard(index: legIdx)
            }
            
            if vm.billingLegs.count < maxLegs {
                Button {
                    withAnimation { vm.addBillingLeg(maxLegs: maxLegs) }
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Payment Leg")
                            .font(BrandFont.body(14, weight: .semibold))
                    }
                    .foregroundStyle(Color.brandWarmBlack)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.brandLinen)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color.brandPebble, lineWidth: 0.5))
                }
                .padding(.horizontal, Spacing.md)
            }
        }
    }

    private func legCard(index: Int) -> some View {
        let leg = vm.billingLegs[index]
        return VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Leg \(leg.legNumber)")
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundStyle(Color.brandWarmBlack)
                    
                    // Leg status badge
                    switch leg.existingStatus {
                    case "paid":
                        Text("✅ Paid")
                            .font(BrandFont.body(11, weight: .semibold))
                            .foregroundStyle(Color(hex: "#4A7C59"))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color(hex: "#4A7C59").opacity(0.1))
                            .clipShape(Capsule())
                    case "partially_paid":
                        Text("⏳ Partial")
                            .font(BrandFont.body(11, weight: .semibold))
                            .foregroundStyle(Color(hex: "#C8913A"))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color(hex: "#C8913A").opacity(0.1))
                            .clipShape(Capsule())
                    case "pending":
                        Text("🕐 Pending")
                            .font(BrandFont.body(11, weight: .semibold))
                            .foregroundStyle(Color.brandWarmGrey)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.brandPebble.opacity(0.2))
                            .clipShape(Capsule())
                    default:
                        EmptyView()
                    }
                }
                
                Spacer()
                
                // Due type toggle — locked if any item is paid
                if leg.hasAnyPaidItem {
                    Text(leg.dueType == "immediate" ? "Now" : "Later")
                        .font(BrandFont.body(13, weight: .bold))
                        .foregroundStyle(Color.brandWarmGrey)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.brandPebble.opacity(0.1))
                        .clipShape(Capsule())
                } else {
                    Picker("Due Type", selection: $vm.billingLegs[index].dueType) {
                        Text("Now").tag("immediate")
                        Text("Later").tag("on_delivery")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                }
                
                // Only allow removing leg if it has no paid items
                if !leg.hasAnyPaidItem && vm.billingLegs.count > 1 {
                    Button {
                        withAnimation { vm.removeBillingLeg(at: index) }
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(Color(hex: "#9B4444"))
                    }
                    .padding(.leading, 8)
                }
            }
            
            HStack {
                Text("Leg Total")
                    .font(BrandFont.body(13))
                    .foregroundStyle(Color.brandWarmGrey)
                Spacer()
                TextField("Leg total", value: Binding(
                    get: { vm.billingLegs[index].totalAmount },
                    set: { vm.updateLegAmount(at: index, to: $0) }
                ), format: .number)
                    .disabled(leg.isFullyLocked || leg.hasAnyPaidItem)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(BrandFont.body(15, weight: .bold))
                    .foregroundStyle(leg.isFullyLocked ? Color.brandWarmGrey : Color.brandWarmBlack)
                    .frame(width: 100)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(leg.isFullyLocked ? Color.brandPebble.opacity(0.15) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            
            BrandDivider()
            
            ForEach(leg.items.indices, id: \.self) { itemIdx in
                legItemRow(legIdx: index, itemIdx: itemIdx)
            }
            
            // Only show Add Split if:
            // 1. leg is not fully paid
            // 2. items count < maxSplits
            // 3. there are at least 2 enabled methods
            if !leg.isFullyLocked && leg.items.count < maxSplits && vm.enabledPaymentMethods.count > 1 {
                Button {
                    withAnimation { vm.addSplitItem(to: index, maxSplits: maxSplits) }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 13))
                        Text("Add Split")
                            .font(BrandFont.body(13))
                    }
                    .foregroundStyle(Color.brandWarmGrey)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.brandOffWhite)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.brandPebble, lineWidth: 0.5))
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.brandLinen)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.brandPebble, lineWidth: 0.5))
        .padding(.horizontal, Spacing.md)
    }

    private func legItemRow(legIdx: Int, itemIdx: Int) -> some View {
        let item = vm.billingLegs[legIdx].items[itemIdx]
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(vm.enabledPaymentMethods, id: \.self) { method in
                            Button {
                                if item.isPending {
                                    vm.billingLegs[legIdx].items[itemIdx].method = method
                                }
                            } label: {
                                Text(method.uppercased())
                                    .font(BrandFont.body(12, weight: .medium))
                                    .foregroundStyle(
                                        item.method == method
                                        ? (item.isPaid ? Color(hex: "#4A7C59") : Color.brandOffWhite)
                                        : Color.brandWarmBlack
                                    )
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(
                                        item.method == method
                                        ? (item.isPaid ? Color(hex: "#4A7C59").opacity(0.15) : Color.brandWarmBlack)
                                        : Color.brandLinen
                                    )
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(
                                            item.isPaid ? Color(hex: "#4A7C59").opacity(0.4) : Color.brandPebble,
                                            lineWidth: 0.5
                                        )
                                    )
                                    .opacity(item.isPaid && item.method != method ? 0.3 : 1.0)
                            }
                            .buttonStyle(.plain)
                            .disabled(item.isPaid)
                        }
                    }
                }
                
                Spacer()
                
                // Only show delete if item is new or pending AND leg has more than 1 item
                if !item.isPaid && vm.billingLegs[legIdx].items.count > 1 {
                    Button {
                        withAnimation { vm.removeSplitItem(from: legIdx, itemIndex: itemIdx) }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Color(hex: "#9B4444"))
                    }
                    .buttonStyle(.plain)
                }
            }
            
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Amount")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.brandWarmGrey)
                    HStack {
                        TextField("0.00", value: Binding(
                            get: { vm.billingLegs[legIdx].items[itemIdx].amount },
                            set: { vm.updateSplitAmount(legIndex: legIdx, itemIndex: itemIdx, to: $0) }
                        ), format: .number)
                            .disabled(item.isPaid)
                            .keyboardType(.decimalPad)
                            .font(BrandFont.body(14, weight: .semibold))
                            .foregroundStyle(item.isPaid ? Color.brandWarmGrey : Color.brandWarmBlack)
                        
                        // Status icon
                        if item.isPaid {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(hex: "#4A7C59"))
                                .font(.system(size: 16))
                        } else if item.existingStatus == "pending" {
                            Image(systemName: "clock")
                                .foregroundStyle(Color(hex: "#C8913A"))
                                .font(.system(size: 16))
                        }
                    }
                    .padding(10)
                    .background(item.isPaid ? Color.brandPebble.opacity(0.15) : Color.brandOffWhite)
                    .cornerRadius(Radius.sm)
                }
                
                if item.method == "cash" && !item.isPaid {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tendered")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.brandWarmGrey)
                        TextField("0.00", value: $vm.billingLegs[legIdx].items[itemIdx].tendered, format: .number)
                            .keyboardType(.decimalPad)
                            .font(BrandFont.body(14, weight: .semibold))
                            .padding(10)
                            .background(Color.brandOffWhite)
                            .cornerRadius(Radius.sm)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Note")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.brandWarmGrey)
                        Text(item.isPaid ? "Payment Collected" : "To be collected via \(vm.activeGateway.capitalized)")
                            .font(BrandFont.body(12))
                            .foregroundStyle(Color.brandWarmGrey)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.brandOffWhite.opacity(0.5))
                            .cornerRadius(Radius.sm)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.brandOffWhite.opacity(0.3))
        .cornerRadius(Radius.md)
    }

    private var validationSection: some View {
        let assignedTotal = vm.billingLegs.reduce(0.0) { $0 + $1.totalAmount }
        let diff = vm.cartTotal - assignedTotal
        let isBalanced = abs(diff) < 0.01
        
        return VStack(spacing: 12) {
            VStack(spacing: 8) {
                HStack {
                    Text("Order Total: ₹\(Int(vm.cartTotal))")
                        .font(BrandFont.body(12, weight: .bold))
                    Spacer()
                    if isBalanced {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Balanced")
                        }
                        .font(BrandFont.body(12, weight: .bold))
                        .foregroundStyle(Color(hex: "#4A7C59"))
                    } else {
                        Text(diff > 0 ? "Short: ₹\(Int(diff))" : "Over: ₹\(Int(abs(diff)))")
                            .font(BrandFont.body(12, weight: .bold))
                            .foregroundStyle(Color(hex: "#9B4444"))
                    }
                }
                
                BrandDivider()
                
                // Per-leg breakdown
                ForEach(vm.billingLegs.indices, id: \.self) { i in
                    let leg = vm.billingLegs[i]
                    HStack {
                        Text("Leg \(leg.legNumber)")
                            .font(BrandFont.body(12))
                            .foregroundStyle(Color.brandWarmGrey)
                        Spacer()
                        if leg.lockedAmount > 0 {
                            Text("₹\(Int(leg.lockedAmount)) paid")
                                .font(BrandFont.body(11, weight: .semibold))
                                .foregroundStyle(Color(hex: "#4A7C59"))
                                .padding(.trailing, 4)
                        }
                        if leg.pendingAmount > 0 {
                            Text("₹\(Int(leg.pendingAmount)) pending")
                                .font(BrandFont.body(11, weight: .semibold))
                                .foregroundStyle(Color(hex: "#C8913A"))
                        }
                    }
                }
            }
            .padding(Spacing.md)
            .background(Color.brandLinen)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Color.brandPebble, lineWidth: 0.5)
            )
        }
        .padding(.horizontal, Spacing.md)
    }

    private var gatewayStatusSection: some View {
        HStack {
            if vm.gatewayConfigured {
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: "#4A7C59")).frame(width: 8, height: 8)
                    Text("\(vm.activeGateway.capitalized) connected")
                        .font(BrandFont.body(12, weight: .medium))
                        .foregroundStyle(Color(hex: "#4A7C59"))
                }
            } else {
                HStack(spacing: 6) {
                    Circle().fill(Color(hex: "#C8913A")).frame(width: 8, height: 8)
                    Text("Cash only — no gateway configured")
                        .font(BrandFont.body(12, weight: .medium))
                        .foregroundStyle(Color(hex: "#C8913A"))
                }
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.md)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            if let error = vm.errorMessage {
                ErrorBanner(message: error) { vm.errorMessage = nil }
                    .padding(.bottom, 4)
            }

            Button {
                Task {
                    await vm.submitBilling(
                        appointmentId: appointmentId,
                        action: "save",
                        orderStore: orderStore
                    )
                    if vm.errorMessage == nil {
                        showDraftSavedToast = true
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        showDraftSavedToast = false
                    }
                }
            } label: {
                HStack {
                    if vm.isLoading {
                        ProgressView().tint(Color.brandWarmBlack)
                    } else {
                        Text("Save Billing Plan")
                            .font(BrandFont.body(15, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.brandLinen)
                .foregroundStyle(Color.brandWarmBlack)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color.brandPebble, lineWidth: 1))
            }
            .disabled(vm.isLoading)

            let assignedTotal = vm.billingLegs.reduce(0.0) { $0 + $1.totalAmount }
            let isBalanced = abs(vm.cartTotal - assignedTotal) < 0.01

            PrimaryButton(
                title: "Mark as Paid & Confirm",
                isLoading: vm.isLoading,
                isDisabled: !isBalanced
            ) {
                Task {
                    await vm.submitBilling(appointmentId: appointmentId, action: "mark_as_paid", orderStore: orderStore)
                    if vm.errorMessage == nil && !vm.showReceipt {
                         // If it opened checkout, we don't dismiss yet.
                         // But if it finished (cash), we show receipt.
                    }
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.brandOffWhite)
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: -5)
    }
}
