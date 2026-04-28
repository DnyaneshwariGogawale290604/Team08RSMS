import SwiftUI

struct BillingView: View {
    @ObservedObject var vm: AssociateSalesViewModel
    @EnvironmentObject var orderStore: SharedOrderStore
    @Environment(\.dismiss) var dismiss
    @State private var showDraftSavedToast = false
    @State private var showReceiptUrl: String? = nil
    
    let appointmentId: UUID?
    let maxLegs: Int      // from gateway config
    let maxSplits: Int    // from gateway config

    var body: some View {
        NavigationStack {
            ZStack {
                Color.luxuryBackground.ignoresSafeArea()

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
                                .foregroundStyle(Color.luxuryPrimary)
                                .font(.system(size: 16))
                            Text("Billing plan saved")
                                .font(BrandFont.body(13, weight: .medium))
                                .foregroundStyle(Color.luxuryPrimaryText)
                            Spacer()
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.lg)
                                .fill(Color.luxurySurface)
                                .shadow(color: Color.luxuryPrimaryText.opacity(0.12),
                                        radius: 12, y: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.lg)
                                .stroke(Color.luxuryPrimary.opacity(0.3),
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
                        .foregroundStyle(Color.luxuryPrimaryText)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.luxurySecondaryText)
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
                                .foregroundStyle(Color.luxuryPrimaryText)
                            Text("₹\(Int(item.product.price)) × \(item.quantity)")
                                .font(BrandFont.body(12))
                                .foregroundStyle(Color.luxurySecondaryText)
                        }
                        Spacer()
                        Text("₹\(Int(item.lineTotal))")
                            .font(BrandFont.body(14, weight: .semibold))
                            .foregroundStyle(Color.luxuryPrimaryText)
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
                        .foregroundStyle(Color.luxuryPrimaryText)
                    Spacer()
                    Text("₹\(Int(vm.cartTotal))")
                        .font(.system(size: 20, weight: .bold, design: .serif))
                        .foregroundStyle(Color.luxuryPrimaryText)
                }
                .padding(Spacing.md)
                .background(Color.luxurySurface.opacity(0.5))
            }
            .background(Color.luxurySurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.luxuryDivider, lineWidth: 0.5))
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
                    .foregroundStyle(Color.luxuryPrimaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.luxurySurface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color.luxuryDivider, lineWidth: 0.5))
                }
                .padding(.horizontal, Spacing.md)
            }
        }
    }

    @ViewBuilder
    private func legCard(index: Int) -> some View {
        if index < vm.billingLegs.count {
            let leg = vm.billingLegs[index]
            VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Leg \(leg.legNumber)")
                        .font(.system(size: 15, weight: .bold, design: .serif))
                        .foregroundStyle(Color.luxuryPrimaryText)
                    
                    // Leg status badge
                    switch leg.existingStatus {
                    case "paid":
                        Text("✅ Paid")
                            .font(BrandFont.body(11, weight: .semibold))
                            .foregroundStyle(Color.luxuryPrimary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.luxuryPrimary.opacity(0.1))
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
                            .foregroundStyle(Color.luxurySecondaryText)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.luxuryDivider.opacity(0.2))
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
                        .foregroundStyle(Color.luxurySecondaryText)
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.luxuryDivider.opacity(0.1))
                        .clipShape(Capsule())
                } else {
                    Picker("Due Type", selection: Binding(
                        get: { index < vm.billingLegs.count ? vm.billingLegs[index].dueType : "immediate" },
                        set: { if index < vm.billingLegs.count { vm.billingLegs[index].dueType = $0 } }
                    )) {
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
                    .foregroundStyle(Color.luxurySecondaryText)
                Spacer()
                TextField("Leg total", value: Binding<Double?>(
                    get: { index < vm.billingLegs.count ? (vm.billingLegs[index].totalAmount == 0 ? nil : vm.billingLegs[index].totalAmount) : nil },
                    set: { vm.updateLegAmount(at: index, to: $0 ?? 0.0) }
                ), format: .number)
                    .disabled(leg.isFullyLocked || leg.hasAnyPaidItem)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .font(BrandFont.body(15, weight: .bold))
                    .foregroundStyle(leg.isFullyLocked ? Color.luxurySecondaryText : Color.luxuryPrimaryText)
                    .frame(width: 100)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(leg.isFullyLocked ? Color.luxuryDivider.opacity(0.15) : Color.clear)
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
                    .foregroundStyle(Color.luxurySecondaryText)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(Color.luxuryBackground)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.luxuryDivider, lineWidth: 0.5))
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.luxurySurface)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.luxuryDivider, lineWidth: 0.5))
        .padding(.horizontal, Spacing.md)
        }
    }

    @ViewBuilder
    private func legItemRow(legIdx: Int, itemIdx: Int) -> some View {
        if legIdx < vm.billingLegs.count, itemIdx < vm.billingLegs[legIdx].items.count {
            let item = vm.billingLegs[legIdx].items[itemIdx]
            let leg = vm.billingLegs[legIdx]

            VStack(alignment: .leading, spacing: 12) {
            // Row 1: Method pills + delete button
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
                                        ? (item.isPaid
                                           ? Color(hex: "#4A7C59")
                                           : Color.luxuryBackground)
                                        : Color.luxuryPrimaryText
                                    )
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        item.method == method
                                        ? (item.isPaid
                                           ? Color(hex: "#4A7C59").opacity(0.15)
                                           : Color.luxuryPrimaryText)
                                        : Color.luxurySurface
                                    )
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule().stroke(
                                            item.isPaid
                                            ? Color(hex: "#4A7C59").opacity(0.4)
                                            : Color.luxuryDivider,
                                            lineWidth: 0.5
                                        )
                                    )
                                    .opacity(
                                        item.isPaid && item.method != method
                                        ? 0.3 : 1.0
                                    )
                            }
                            .buttonStyle(.plain)
                            .disabled(item.isPaid)
                        }
                    }
                }

                Spacer()

                // Delete button — only if pending and leg > 1 item
                if !item.isPaid && leg.items.count > 1 {
                    Button {
                        withAnimation {
                            vm.removeSplitItem(from: legIdx, itemIndex: itemIdx)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Color(hex: "#9B4444"))
                            .font(.system(size: 14))
                    }
                    .buttonStyle(.plain)
                }
            }

            // Row 2: Amount + Tendered (cash) or status label
            HStack(spacing: 12) {
                // Amount field
                VStack(alignment: .leading, spacing: 4) {
                    Text("AMOUNT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.luxurySecondaryText)
                    HStack {
                        TextField("0.00",
                            value: Binding<Double?>(
                                get: {
                                    guard legIdx < vm.billingLegs.count, itemIdx < vm.billingLegs[legIdx].items.count else { return nil }
                                    let val = vm.billingLegs[legIdx].items[itemIdx].amount
                                    return val == 0 ? nil : val
                                },
                                set: { vm.updateSplitAmount(legIndex: legIdx, itemIndex: itemIdx, to: $0 ?? 0.0) }
                            ),
                            format: .number
                        )
                        .disabled(item.isPaid)
                        .keyboardType(.decimalPad)
                        .font(BrandFont.body(14, weight: .semibold))
                        .foregroundStyle(
                            item.isPaid
                            ? Color.luxurySecondaryText
                            : Color.luxuryPrimaryText
                        )

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
                    .background(
                        item.isPaid
                        ? Color.luxuryDivider.opacity(0.15)
                        : Color.luxuryBackground
                    )
                    .cornerRadius(Radius.sm)
                }

                // Tendered field — cash only, not paid
                if item.method == "cash" && !item.isPaid {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("TENDERED")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.luxurySecondaryText)
                        TextField("0.00",
                            value: Binding(
                                get: { (legIdx < vm.billingLegs.count && itemIdx < vm.billingLegs[legIdx].items.count) ? vm.billingLegs[legIdx].items[itemIdx].tendered : nil },
                                set: { if legIdx < vm.billingLegs.count && itemIdx < vm.billingLegs[legIdx].items.count { vm.billingLegs[legIdx].items[itemIdx].tendered = $0 } }
                            ),
                            format: .number
                        )
                        .keyboardType(.decimalPad)
                        .font(BrandFont.body(14, weight: .semibold))
                        .padding(10)
                        .background(Color.luxuryBackground)
                        .cornerRadius(Radius.sm)
                    }
                } else if item.method != "cash" && !item.isPaid {
                    // Gateway note
                    VStack(alignment: .leading, spacing: 4) {
                        Text("GATEWAY")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color.luxurySecondaryText)
                        Text("Via \(vm.activeGateway.capitalized)")
                            .font(BrandFont.body(12))
                            .foregroundStyle(Color.luxurySecondaryText)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.luxuryBackground.opacity(0.5))
                            .cornerRadius(Radius.sm)
                    }
                }
            }

            // Row 3: Change display for cash
            if item.method == "cash" && !item.isPaid,
               let tendered = item.tendered, tendered > 0 {
                let change = tendered - item.amount
                HStack {
                    Text(change >= 0 ? "Change to return:" : "Short by:")
                        .font(BrandFont.body(12))
                        .foregroundStyle(Color.luxurySecondaryText)
                    Spacer()
                    Text("₹\(abs(Int(change)))")
                        .font(BrandFont.body(13, weight: .semibold))
                        .foregroundStyle(
                            change >= 0
                            ? Color(hex: "#4A7C59")
                            : Color(hex: "#9B4444")
                        )
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    (change >= 0
                     ? Color(hex: "#4A7C59")
                     : Color(hex: "#9B4444")).opacity(0.08)
                )
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
            }

            // Row 4: Action button per item
            itemActionButton(
                legIdx: legIdx,
                itemIdx: itemIdx,
                item: item
            )
        }
        .padding(12)
        .background(Color.luxuryBackground.opacity(0.3))
        .cornerRadius(Radius.md)
        }
    }

    private func itemActionButton(
        legIdx: Int,
        itemIdx: Int,
        item: BillingLegItem
    ) -> some View {
        Group {
            if item.isPaid {
                // Paid state
                if item.method == "cash" {
                    // Cash — just show paid badge, no button
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color(hex: "#4A7C59"))
                            .font(.system(size: 13))
                        Text("Cash Received")
                            .font(BrandFont.body(12, weight: .medium))
                            .foregroundStyle(Color(hex: "#4A7C59"))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(hex: "#4A7C59").opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))

                } else {
                    // Gateway — show "View Bill" button
                    Button {
                        // Open Razorpay receipt URL
                        if let summary = vm.orderPaymentSummary {
                            let legs = summary.legs
                            if legIdx < legs.count {
                                let legRecord = legs[legIdx]
                                if itemIdx < legRecord.items.count {
                                    let itemRecord = legRecord.items[itemIdx]
                                    if let urlString = itemRecord.receiptUrl,
                                       let url = URL(string: urlString) {
                                        UIApplication.shared.open(url)
                                    }
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text")
                                .font(.system(size: 13))
                            Text("View Bill")
                                .font(BrandFont.body(13, weight: .semibold))
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 11))
                        }
                        .foregroundStyle(Color.luxuryPrimaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.luxurySurface)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .stroke(Color.luxuryDivider, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }

            } else {
                // Pending state
                if item.method == "cash" {
                    // Cash confirm button
                    Button {
                        Task {
                            await vm.collectCashItem(
                                legIndex: legIdx,
                                itemIndex: itemIdx,
                                appointmentId: appointmentId
                            )
                        }
                    } label: {
                        HStack {
                            if vm.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(Color.luxuryBackground)
                            } else {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .semibold))
                                Text("Confirm Cash Received")
                                    .font(BrandFont.body(13, weight: .semibold))
                            }
                            Spacer()
                        }
                        .foregroundStyle(Color.luxuryBackground)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.luxuryPrimaryText)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isLoading || item.amount <= 0)

                } else {
                    // Gateway collect button
                    Button {
                        Task {
                            await vm.initiateGatewayPaymentForItem(
                                legIndex: legIdx,
                                itemIndex: itemIdx,
                                appointmentId: appointmentId
                            )
                        }
                    } label: {
                        HStack {
                            if vm.isLoading {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(Color.luxuryPrimaryText)
                            } else {
                                Image(systemName: "creditcard")
                                    .font(.system(size: 13))
                                Text("Pay via Gateway")
                                    .font(BrandFont.body(13, weight: .semibold))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11))
                                .foregroundStyle(Color.luxurySecondaryText)
                        }
                        .foregroundStyle(Color.luxuryPrimaryText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color.luxurySurface)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.md)
                                .stroke(Color.luxuryDivider, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(vm.isLoading || item.amount <= 0)
                }
            }
        }
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
                        .foregroundStyle(Color.luxuryPrimary)
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
                            .foregroundStyle(Color.luxurySecondaryText)
                        Spacer()
                        if leg.lockedAmount > 0 {
                            Text("₹\(Int(leg.lockedAmount)) paid")
                                .font(BrandFont.body(11, weight: .semibold))
                                .foregroundStyle(Color.luxuryPrimary)
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
            .background(Color.luxurySurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(Color.luxuryDivider, lineWidth: 0.5)
            )
        }
        .padding(.horizontal, Spacing.md)
    }

    private var gatewayStatusSection: some View {
        HStack {
            if vm.gatewayConfigured {
                HStack(spacing: 6) {
                    Circle().fill(Color.luxuryPrimary).frame(width: 8, height: 8)
                    Text("\(vm.activeGateway.capitalized) connected")
                        .font(BrandFont.body(12, weight: .medium))
                        .foregroundStyle(Color.luxuryPrimary)
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

            // Validation warning for unpaid immediate legs
            let hasUnpaidImmediateItems = vm.billingLegs
                .filter { $0.dueType == "immediate" }
                .flatMap { $0.items }
                .contains { !$0.isPaid }

            if hasUnpaidImmediateItems {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(Color(hex: "#C8913A"))
                        .font(.system(size: 13))
                    Text("Complete all immediate payments to checkout")
                        .font(BrandFont.body(12))
                        .foregroundStyle(Color.luxurySecondaryText)
                    Spacer()
                }
                .padding(Spacing.md)
                .background(Color(hex: "#C8913A").opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(Color(hex: "#C8913A").opacity(0.3),
                                lineWidth: 0.5)
                )
            }

            // Save Billing Plan button (always available)
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
                        ProgressView().tint(Color.luxuryPrimaryText)
                    } else {
                        Text("Save Billing Plan")
                            .font(BrandFont.body(15, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.luxurySurface)
                .foregroundStyle(Color.luxuryPrimaryText)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.md)
                        .stroke(Color.luxuryDivider, lineWidth: 1)
                )
            }
            .disabled(vm.isLoading)

            // Checkout button
            // Disabled if any immediate leg item is unpaid
            Button {
                if let apptId = appointmentId {
                    Task {
                        await vm.checkoutAppointment(
                            appointmentId: apptId,
                            orderStore: orderStore
                        ) {
                            dismiss()
                        }
                    }
                } else {
                    // No appointment — direct order completion
                    vm.showBilling = false
                    vm.showReceipt = true
                }
            } label: {
                HStack {
                    if vm.isLoading {
                        ProgressView().tint(Color.luxuryBackground)
                    } else {
                        Text("Checkout")
                            .font(BrandFont.body(15, weight: .semibold))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    hasUnpaidImmediateItems
                    ? Color.luxuryPrimaryText.opacity(0.3)
                    : Color.luxuryPrimaryText
                )
                .foregroundStyle(Color.luxuryBackground)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            }
            .disabled(vm.isLoading || hasUnpaidImmediateItems)
        }
        .padding(Spacing.md)
        .background(Color.luxuryBackground)
        .shadow(color: Color.black.opacity(0.05), radius: 10, y: -5)
    }
}
