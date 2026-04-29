import SwiftUI
import Supabase
import Auth

struct BillAndPaymentsView: View {
    @ObservedObject var vm: AssociateSalesViewModel
    @Environment(\.dismiss) var dismiss
    let salesOrderId: UUID
    
    @State private var paymentMethod: String = "online"
    @State private var splitAmounts: [Double] = []
    @State private var activeLegIndex: Int = -1 // To track which leg we are paying into

    var body: some View {
        NavigationStack {
            ZStack {
                Color.luxuryBackground.ignoresSafeArea()

                if vm.isLoadingPaymentSummary {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Fetching payment details...")
                            .font(BrandFont.body(14))
                            .foregroundStyle(Color.luxurySecondaryText)
                            .padding(.top, 10)
                    }
                } else if let summary = vm.orderPaymentSummary {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: Spacing.lg) {
                            summaryHeader(summary)
                            
                            ForEach(summary.legs) { leg in
                                legRow(leg)
                            }
                            
                            if !summary.isFullyPaid {
                                collectRemainingSection(summary)
                            }
                        }
                        .padding(.vertical, Spacing.lg)
                    }
                } else {
                    VStack {
                        Image(systemName: "creditcard.and.123")
                            .font(.system(size: 48))
                            .foregroundStyle(Color.luxuryDivider)
                        Text("No payment info found.")
                            .font(BrandFont.body(14))
                            .foregroundStyle(Color.luxurySecondaryText)
                    }
                }

                if vm.isLoading {
                    Color.black.opacity(0.05).ignoresSafeArea()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Bill & Payments")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.luxuryPrimaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "checkmark").font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundStyle(Color.luxuryPrimaryText)
                }
            }
            .task {
                await vm.fetchOrderPaymentSummary(salesOrderId: salesOrderId.uuidString)
            }
            .alert("Success", isPresented: Binding(
                get: { vm.successMessage != nil },
                set: { if !$0 { vm.successMessage = nil } }
            )) {
                Button("OK") { vm.successMessage = nil }
            } message: { Text(vm.successMessage ?? "") }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenRazorpayCheckout"))) { _ in
                vm.openRazorpayCheckout()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenCashfreeCheckout"))) { _ in
                // Placeholder
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("OpenPayUCheckout"))) { _ in
                // Placeholder
            }
        }
    }

    private func summaryHeader(_ summary: OrderPaymentSummary) -> some View {
        VStack(spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Amount")
                        .font(BrandFont.body(12))
                        .foregroundStyle(Color.luxurySecondaryText)
                    Text("₹\(Int(summary.totalAmount))")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundStyle(Color.luxuryPrimaryText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Status")
                        .font(BrandFont.body(12))
                        .foregroundStyle(Color.luxurySecondaryText)
                    BadgeView(
                        text: summary.paymentStatus.capitalized,
                        color: summary.paymentStatus == "paid" ? Color.luxuryPrimary : Color(hex: "#C8913A")
                    )
                }
            }
            
            BrandDivider()
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Paid")
                        .font(BrandFont.body(11))
                        .foregroundStyle(Color.luxurySecondaryText)
                    Text("₹\(Int(summary.amountPaid))")
                        .font(BrandFont.body(15, weight: .bold))
                        .foregroundStyle(Color.luxuryPrimary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Remaining")
                        .font(BrandFont.body(11))
                        .foregroundStyle(Color.luxurySecondaryText)
                    Text("₹\(Int(summary.remaining))")
                        .font(BrandFont.body(15, weight: .bold))
                        .foregroundStyle(summary.remaining > 0 ? Color(hex: "#9B4444") : Color.luxurySecondaryText)
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.luxuryDivider, lineWidth: 0.5))
        .padding(.horizontal, Spacing.md)
    }

    private func legRow(_ leg: PaymentLegRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Leg \(leg.legNumber) — \(leg.dueType == "immediate" ? "Initial" : "On Delivery")")
                    .font(BrandFont.body(14, weight: .bold))
                    .foregroundStyle(Color.luxuryPrimaryText)
                
                Spacer()
                
                BadgeView(
                    text: leg.status.capitalized,
                    color: leg.status == "paid" ? Color.luxuryPrimary : Color(hex: "#C8913A")
                )
            }
            
            HStack {
                Text("Amount Due")
                    .font(BrandFont.body(13))
                    .foregroundStyle(Color.luxurySecondaryText)
                Spacer()
                Text("₹\(Int(leg.totalAmount))")
                    .font(BrandFont.body(15, weight: .semibold))
                    .foregroundStyle(Color.luxuryPrimaryText)
            }
            
            if leg.amountPaid > 0 {
                HStack {
                    Text("Amount Paid")
                        .font(BrandFont.body(13))
                        .foregroundStyle(Color.luxurySecondaryText)
                    Spacer()
                    Text("₹\(Int(leg.amountPaid))")
                        .font(BrandFont.body(15, weight: .semibold))
                        .foregroundStyle(Color.luxuryPrimary)
                }
            }
            
            BrandDivider()
            
            ForEach(leg.items) { item in
                HStack {
                    Image(systemName: item.method == "cash" ? "banknote" : "creditcard")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.luxurySecondaryText)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.method.capitalized)
                            .font(.system(size: 10, weight: .bold))
                        if let note = item.note {
                            Text(note)
                                .font(BrandFont.body(11))
                                .foregroundStyle(Color.luxurySecondaryText)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("₹\(Int(item.amount))")
                            .font(BrandFont.body(13, weight: .medium))
                        Text(item.status.capitalized)
                            .font(.system(size: 9))
                            .foregroundStyle(item.status == "paid" ? Color.luxuryPrimary : Color(hex: "#C8913A"))
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(Spacing.md)
        .background(Color.luxurySurface.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.luxuryDivider, lineWidth: 0.5))
        .padding(.horizontal, Spacing.md)
    }

    private func collectRemainingSection(_ summary: OrderPaymentSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionHeader(title: "Collect Remaining Balance")
            
            // Method Toggle
            HStack(spacing: 0) {
                ForEach(["online", "cash"], id: \.self) { method in
                    Button {
                        paymentMethod = method
                    } label: {
                        Text(method.capitalized)
                            .font(BrandFont.body(11, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(paymentMethod == method ? Color.luxuryPrimaryText : Color.clear)
                            .foregroundStyle(paymentMethod == method ? Color.luxuryBackground : Color.luxurySecondaryText)
                    }
                    .clipShape(Capsule())
                }
            }
            .padding(4)
            .background(Color.luxuryDivider.opacity(0.2))
            .clipShape(Capsule())
            .padding(.horizontal, Spacing.md)

            // Splits Logic
            let remaining = summary.remaining
            let currentSplits = splitAmounts.isEmpty ? [remaining] : splitAmounts
            
            VStack(spacing: 12) {
                ForEach(0..<currentSplits.count, id: \.self) { index in
                    VStack(spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Amount").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.luxurySecondaryText)
                                TextField("0", value: Binding(
                                    get: { currentSplits[index] },
                                    set: { val in
                                        if splitAmounts.isEmpty { splitAmounts = [remaining] }
                                        splitAmounts[index] = val
                                    }
                                ), format: .number)
                                .keyboardType(.decimalPad)
                                .font(.system(size: 18, weight: .semibold, design: .serif))
                                .padding(Spacing.md)
                                .background(Color.luxuryBackground)
                                .cornerRadius(Radius.md)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Gateway").font(.system(size: 10, weight: .bold)).foregroundStyle(Color.luxurySecondaryText)
                                Text(paymentMethod == "cash" ? "Record Cash" : "Via \(vm.activeGateway.capitalized)")
                                    .font(BrandFont.body(14))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(Spacing.md)
                                    .background(Color.luxuryBackground.opacity(0.5))
                                    .cornerRadius(Radius.md)
                            }
                        }
                        
                        Button {
                            Task {
                                await collectPayment(method: paymentMethod, amount: currentSplits[index], summary: summary)
                            }
                        } label: {
                            HStack {
                                Image(systemName: paymentMethod == "cash" ? "banknote" : "creditcard")
                                Text(paymentMethod == "cash" ? "Record Cash Payment" : "Pay via Gateway")
                                    .font(BrandFont.body(14, weight: .bold))
                                Spacer()
                                Image(systemName: "chevron.right")
                            }
                            .padding(Spacing.md)
                            .background(Color.white)
                            .cornerRadius(Radius.md)
                            .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color.luxuryDivider, lineWidth: 1))
                        }
                        .foregroundStyle(Color.luxuryPrimaryText)
                        .disabled(vm.isLoading)
                    }
                    .padding(Spacing.md)
                    .background(Color.luxurySurface.opacity(0.4))
                    .cornerRadius(Radius.lg)
                }
                
                if currentSplits.count < vm.maxLegSplits {
                    Button {
                        if splitAmounts.isEmpty { splitAmounts = [remaining] }
                        let currentTotal = splitAmounts.reduce(0, +)
                        if currentTotal < remaining {
                            splitAmounts.append(remaining - currentTotal)
                        } else {
                            splitAmounts.append(0)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Split").font(BrandFont.body(13))
                        }
                        .foregroundStyle(Color.luxuryPrimary)
                    }
                    .padding(.top, 8)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
        .padding(.bottom, 40)
    }



    private func collectPayment(method: String, amount: Double, summary: OrderPaymentSummary) async {
        vm.isLoading = true
        vm.errorMessage = nil
        
        // Prepare context for gateway if needed
        vm.remainingPaymentAmount = amount
        vm.currentPaymentLegIndex = -1
        vm.currentPaymentItemIndex = -1
        
        do {
            let brandId = try await vm.fetchBrandId()
            let session = try await SupabaseManager.shared.client.auth.session
            let authId = session.user.id.uuidString

            // Find the first unpaid leg to apply this payment to, or fallback to the last leg if all are "paid"
            let targetLeg = summary.legs.first { $0.status != "paid" } ?? summary.legs.last
            let legId = targetLeg?.id.uuidString
            
            if targetLeg == nil {
                print("[BillAndPaymentsView] WARNING: No legs found in summary!")
            } else if targetLeg?.status == "paid" {
                print("[BillAndPaymentsView] INFO: All legs paid, falling back to Leg \(targetLeg?.legNumber ?? 0)")
            }
            
            var body: [String: Any] = [
                "brand_id": brandId,
                "sales_order_id": summary.orderId,
                "recorded_by": authId,
                "method": method,
                "amount": amount
            ]
            
            if let lid = legId {
                body["payment_leg_id"] = lid
            }
            
            if let apptId = vm.currentAppointmentId?.uuidString {
                body["appointment_id"] = apptId
            }

            if let bodyData = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted),
               let bodyString = String(data: bodyData, encoding: .utf8) {
                print("[BillAndPaymentsView] REQUEST BODY: \(bodyString)")
            }

            let url = URL(string: "https://ionszphvxhffqfwlohiv.supabase.co/functions/v1/collect-remaining-payment")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, _) = try await URLSession.shared.data(for: req)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw NSError(domain: "PaymentError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }

            if let jsonString = String(data: data, encoding: .utf8) {
                print("[BillAndPaymentsView] RESPONSE: \(jsonString)")
            }

            if let error = json["error"] as? String {
                throw NSError(domain: "PaymentError", code: 2, userInfo: [NSLocalizedDescriptionKey: error])
            }

            // Gateway requires SDK logic - matching ViewModel
            let requiresSDK = json["requires_sdk"] as? Bool ?? false
            if requiresSDK,
               let gwOrderId = json["gateway_order_id"] as? String,
               let keyId = json["key_id"] as? String,
               let poId = json["payment_order_id"] as? String {
                
                vm.gatewayOrderId = gwOrderId
                vm.checkoutKey = keyId
                vm.paymentOrderId = poId
                vm.isLoading = false
                
                let gateway = json["gateway"] as? String ?? "razorpay"
                print("[BillAndPaymentsView] Launching \(gateway) for Order \(gwOrderId)")
                
                if gateway == "razorpay" {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenRazorpayCheckout"), object: nil)
                } else if gateway == "cashfree" {
                    vm.cashfreeSessionId = json["payment_session_id"] as? String
                    NotificationCenter.default.post(name: NSNotification.Name("OpenCashfreeCheckout"), object: nil)
                } else if gateway == "payu" {
                    vm.payuHash = json["payu_hash"] as? String
                    NotificationCenter.default.post(name: NSNotification.Name("OpenPayUCheckout"), object: nil)
                }
            } else {
                vm.isLoading = false
                vm.successMessage = "Payment recorded successfully."
                await vm.fetchOrderPaymentSummary(salesOrderId: summary.orderId)
                NotificationCenter.default.post(name: NSNotification.Name("RefreshSalesAssociateDashboard"), object: nil)
            }
        } catch {
            vm.isLoading = false
            vm.errorMessage = error.localizedDescription
        }
    }
}
