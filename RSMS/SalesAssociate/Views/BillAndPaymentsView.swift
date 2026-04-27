import SwiftUI
import Supabase
import Auth

struct BillAndPaymentsView: View {
    @ObservedObject var vm: AssociateSalesViewModel
    @Environment(\.dismiss) var dismiss
    let salesOrderId: UUID

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandOffWhite.ignoresSafeArea()

                if vm.isLoadingPaymentSummary {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Fetching payment details...")
                            .font(BrandFont.body(14))
                            .foregroundStyle(Color.brandWarmGrey)
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
                            .foregroundStyle(Color.brandPebble)
                        Text("No payment info found.")
                            .font(BrandFont.body(14))
                            .foregroundStyle(Color.brandWarmGrey)
                    }
                }

                if vm.isLoading {
                    Color.black.opacity(0.05).ignoresSafeArea()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("BILL & PAYMENTS")
                        .font(.system(size: 13, weight: .semibold))
                        .kerning(2)
                        .foregroundStyle(Color.brandWarmBlack)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(BrandFont.body(14, weight: .semibold))
                        .foregroundStyle(Color.brandWarmBlack)
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
        }
    }

    private func summaryHeader(_ summary: OrderPaymentSummary) -> some View {
        VStack(spacing: Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Total Amount")
                        .font(BrandFont.body(12))
                        .foregroundStyle(Color.brandWarmGrey)
                    Text("₹\(Int(summary.totalAmount))")
                        .font(.system(size: 24, weight: .bold, design: .serif))
                        .foregroundStyle(Color.brandWarmBlack)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Status")
                        .font(BrandFont.body(12))
                        .foregroundStyle(Color.brandWarmGrey)
                    BadgeView(
                        text: summary.paymentStatus.uppercased(),
                        color: summary.paymentStatus == "paid" ? Color(hex: "#4A7C59") : Color(hex: "#C8913A")
                    )
                }
            }
            
            BrandDivider()
            
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Paid")
                        .font(BrandFont.body(11))
                        .foregroundStyle(Color.brandWarmGrey)
                    Text("₹\(Int(summary.amountPaid))")
                        .font(BrandFont.body(15, weight: .bold))
                        .foregroundStyle(Color(hex: "#4A7C59"))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Remaining")
                        .font(BrandFont.body(11))
                        .foregroundStyle(Color.brandWarmGrey)
                    Text("₹\(Int(summary.remaining))")
                        .font(BrandFont.body(15, weight: .bold))
                        .foregroundStyle(summary.remaining > 0 ? Color(hex: "#9B4444") : Color.brandWarmGrey)
                }
            }
        }
        .padding(Spacing.md)
        .background(Color.brandLinen)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.brandPebble, lineWidth: 0.5))
        .padding(.horizontal, Spacing.md)
    }

    private func legRow(_ leg: PaymentLegRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Leg \(leg.legNumber) — \(leg.dueType == "immediate" ? "Initial" : "On Delivery")")
                    .font(BrandFont.body(14, weight: .bold))
                    .foregroundStyle(Color.brandWarmBlack)
                
                Spacer()
                
                BadgeView(
                    text: leg.status.uppercased(),
                    color: leg.status == "paid" ? Color(hex: "#4A7C59") : Color(hex: "#C8913A")
                )
            }
            
            HStack {
                Text("Amount Due")
                    .font(BrandFont.body(13))
                    .foregroundStyle(Color.brandWarmGrey)
                Spacer()
                Text("₹\(Int(leg.totalAmount))")
                    .font(BrandFont.body(15, weight: .semibold))
                    .foregroundStyle(Color.brandWarmBlack)
            }
            
            if leg.amountPaid > 0 {
                HStack {
                    Text("Amount Paid")
                        .font(BrandFont.body(13))
                        .foregroundStyle(Color.brandWarmGrey)
                    Spacer()
                    Text("₹\(Int(leg.amountPaid))")
                        .font(BrandFont.body(15, weight: .semibold))
                        .foregroundStyle(Color(hex: "#4A7C59"))
                }
            }
            
            BrandDivider()
            
            ForEach(leg.items) { item in
                HStack {
                    Image(systemName: item.method == "cash" ? "banknote" : "creditcard")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.brandWarmGrey)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.method.uppercased())
                            .font(.system(size: 10, weight: .bold))
                        if let note = item.note {
                            Text(note)
                                .font(BrandFont.body(11))
                                .foregroundStyle(Color.brandWarmGrey)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("₹\(Int(item.amount))")
                            .font(BrandFont.body(13, weight: .medium))
                        Text(item.status.capitalized)
                            .font(.system(size: 9))
                            .foregroundStyle(item.status == "paid" ? Color(hex: "#4A7C59") : Color(hex: "#C8913A"))
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .padding(Spacing.md)
        .background(Color.brandLinen.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.brandPebble, lineWidth: 0.5))
        .padding(.horizontal, Spacing.md)
    }

    private func collectRemainingSection(_ summary: OrderPaymentSummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Collect Payment")
            
            Text("The customer has an outstanding balance of ₹\(Int(summary.remaining)). Choose a method to record the remaining payment.")
                .font(BrandFont.body(13))
                .foregroundStyle(Color.brandWarmGrey)
                .padding(.horizontal, Spacing.md)
            
            HStack(spacing: 12) {
                paymentOptionButton(title: "UPI", method: "upi", summary: summary)
                paymentOptionButton(title: "Cash", method: "cash", summary: summary)
                paymentOptionButton(title: "Net Banking", method: "netbanking", summary: summary)
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    private func paymentOptionButton(title: String, method: String, summary: OrderPaymentSummary) -> some View {
        let isEnabled = summary.enabledMethods.contains(method)
        
        return Button {
            Task {
                await collectPayment(method: method, summary: summary)
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: iconForMethod(method))
                    .font(.title3)
                Text(title)
                    .font(BrandFont.body(11, weight: .semibold))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isEnabled ? Color.brandWarmBlack : Color.brandPebble)
            .foregroundStyle(isEnabled ? Color.brandOffWhite : Color.brandWarmGrey)
            .cornerRadius(Radius.md)
        }
        .disabled(!isEnabled || vm.isLoading)
    }

    private func iconForMethod(_ method: String) -> String {
        switch method {
        case "upi": return "qrcode"
        case "cash": return "banknote"
        case "netbanking": return "building.columns"
        default: return "creditcard"
        }
    }

    private func collectPayment(method: String, summary: OrderPaymentSummary) async {
        vm.isLoading = true
        vm.errorMessage = nil
        
        do {
            let brandId = try await vm.fetchBrandId()
            let session = try await SupabaseManager.shared.client.auth.session
            let authId = session.user.id.uuidString

            let body: [String: Any] = [
                "brand_id": brandId,
                "sales_order_id": summary.orderId,
                "recorded_by": authId,
                "method": method,
                "amount": summary.remaining
            ]

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

            if let error = json["error"] as? String {
                throw NSError(domain: "PaymentError", code: 2, userInfo: [NSLocalizedDescriptionKey: error])
            }

            // Handle pending gateway payments
            if let pending = json["pending_gateway_payment"] as? [String: Any],
               let gwOrderId = pending["gateway_order_id"] as? String,
               let keyId = pending["key_id"] as? String,
               let poId = pending["payment_order_id"] as? String {
                vm.gatewayOrderId = gwOrderId
                vm.checkoutKey = keyId
                vm.paymentOrderId = poId
                vm.isLoading = false
                NotificationCenter.default.post(name: NSNotification.Name("OpenRazorpayCheckout"), object: nil)
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
