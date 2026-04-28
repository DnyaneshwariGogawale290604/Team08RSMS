import SwiftUI

struct GatewayCollectionSheet: View {
    @ObservedObject var vm: AssociateSalesViewModel
    @Environment(\.dismiss) var dismiss
    let legIndex: Int
    let itemIndex: Int
    let appointmentId: UUID?

    @State private var deliveryMode = ""
    // "qr" = show QR on screen (UPI)
    // "open" = open link on screen (Netbanking)
    // "link" = share link via phone
    // "both" = show QR/Open Link + share link
    @State private var phoneNumber = ""
    @State private var channel = "whatsapp" // "whatsapp" or "sms"
    @State private var linkSent = false

    private var item: BillingLegItem? {
        guard legIndex < vm.billingLegs.count,
              itemIndex < vm.billingLegs[legIndex].items.count
        else { return nil }
        return vm.billingLegs[legIndex].items[itemIndex]
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.luxuryBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.lg) {
                        // Amount card
                        if let item = item {
                            VStack(spacing: 4) {
                                Text("AMOUNT TO COLLECT")
                                    .font(.system(size: 10, weight: .bold))
                                    .kerning(1.2)
                                    .foregroundStyle(Color.luxurySecondaryText)
                                Text("₹\(Int(item.amount))")
                                    .font(.system(size: 32, weight: .bold,
                                                  design: .serif))
                                    .foregroundStyle(Color.luxuryPrimaryText)
                                Text("via \(item.method.uppercased())")
                                    .font(BrandFont.body(12))
                                    .foregroundStyle(Color.luxurySecondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(Spacing.lg)
                            .background(Color.luxurySurface)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                            .overlay(RoundedRectangle(cornerRadius: Radius.lg)
                                .stroke(Color.luxuryDivider, lineWidth: 0.5))
                            .padding(.horizontal, Spacing.md)
                        }

                        // Delivery mode selector
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("COLLECTION METHOD")
                                .font(.system(size: 10, weight: .bold))
                                .kerning(1.2)
                                .foregroundStyle(Color.luxurySecondaryText)
                                .padding(.horizontal, Spacing.md)

                            HStack(spacing: 8) {
                                let modes: [(String, String)] = (item?.method ?? "") == "netbanking"
                                    ? [("open", "Open Link"), ("link", "Share Link"), ("both", "Both")]
                                    : [("qr", "Show QR"), ("link", "Share Link"), ("both", "Both")]
                                
                                ForEach(modes, id: \.0) { mode in
                                    Button {
                                        deliveryMode = mode.0
                                    } label: {
                                        Text(mode.1)
                                            .font(BrandFont.body(13,
                                                weight: .medium))
                                            .foregroundStyle(
                                                deliveryMode == mode.0
                                                ? Color.luxuryBackground
                                                : Color.luxuryPrimaryText
                                            )
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(
                                                deliveryMode == mode.0
                                                ? Color.luxuryPrimaryText
                                                : Color.luxurySurface
                                            )
                                            .clipShape(RoundedRectangle(
                                                cornerRadius: Radius.md))
                                            .overlay(
                                                RoundedRectangle(
                                                    cornerRadius: Radius.md)
                                                    .stroke(Color.luxuryDivider,
                                                            lineWidth: 0.5)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, Spacing.md)
                        }

                        // Netbanking Open Link section
                        if deliveryMode == "open" || (deliveryMode == "both" && (item?.method ?? "") == "netbanking") {
                            VStack(spacing: Spacing.md) {
                                RoundedRectangle(cornerRadius: Radius.lg)
                                    .fill(Color.luxurySurface)
                                    .frame(height: 200)
                                    .overlay(
                                        VStack(spacing: 12) {
                                            Image(systemName: "link.circle")
                                                .font(.system(size: 52))
                                                .foregroundStyle(Color.luxurySecondaryText)
                                            Text("Payment link will appear after initiating")
                                                .font(BrandFont.body(13))
                                                .foregroundStyle(Color.luxurySecondaryText)
                                        }
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Radius.lg)
                                            .stroke(Color.luxuryDivider, lineWidth: 0.5)
                                    )
                            }
                            .padding(.horizontal, Spacing.md)
                        }

                        // QR section (UPI)
                        if deliveryMode == "qr" || (deliveryMode == "both" && (item?.method ?? "") != "netbanking") {
                            VStack(spacing: Spacing.md) {
                                // QR placeholder
                                // Real QR shown after initiateGatewayPaymentForItem
                                RoundedRectangle(cornerRadius: Radius.lg)
                                    .fill(Color.luxurySurface)
                                    .frame(height: 200)
                                    .overlay(
                                        VStack(spacing: 8) {
                                            Image(systemName: "qrcode")
                                                .font(.system(size: 52))
                                                .foregroundStyle(
                                                    Color.luxurySecondaryText)
                                            Text("QR will appear after initiating")
                                                .font(BrandFont.body(13))
                                                .foregroundStyle(
                                                    Color.luxurySecondaryText)
                                        }
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: Radius.lg)
                                            .stroke(Color.luxuryDivider,
                                                    lineWidth: 0.5)
                                    )

                                // App pills
                                HStack(spacing: 8) {
                                    ForEach(["GPay", "PhonePe",
                                             "Paytm", "BHIM"], id: \.self) { app in
                                        Text(app)
                                            .font(BrandFont.body(12,
                                                weight: .medium))
                                            .foregroundStyle(Color.luxuryPrimaryText)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(Color.luxurySurface)
                                            .clipShape(Capsule())
                                            .overlay(Capsule()
                                                .stroke(Color.luxuryDivider,
                                                        lineWidth: 0.5))
                                    }
                                }
                            }
                            .padding(.horizontal, Spacing.md)
                        }

                        // Link section
                        if deliveryMode == "link" || deliveryMode == "both" {
                            VStack(alignment: .leading, spacing: Spacing.sm) {
                                Text("CUSTOMER PHONE")
                                    .font(.system(size: 10, weight: .bold))
                                    .kerning(1.2)
                                    .foregroundStyle(Color.luxurySecondaryText)

                                TextField("Enter phone number",
                                          text: $phoneNumber)
                                    .keyboardType(.phonePad)
                                    .font(BrandFont.body(14))
                                    .padding(Spacing.md)
                                    .background(Color.luxurySurface)
                                    .clipShape(RoundedRectangle(
                                        cornerRadius: Radius.md))
                                    .overlay(RoundedRectangle(
                                        cornerRadius: Radius.md)
                                        .stroke(Color.luxuryDivider,
                                                lineWidth: 0.5))

                                // Channel selector
                                HStack(spacing: 8) {
                                    ForEach([
                                        ("whatsapp", "WhatsApp"),
                                        ("sms", "SMS")
                                    ], id: \.0) { ch in
                                        Button {
                                            channel = ch.0
                                        } label: {
                                            Text(ch.1)
                                                .font(BrandFont.body(13,
                                                    weight: .medium))
                                                .foregroundStyle(
                                                    channel == ch.0
                                                    ? Color.luxuryBackground
                                                    : Color.luxuryPrimaryText
                                                )
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 8)
                                                .background(
                                                    channel == ch.0
                                                    ? Color.luxuryPrimaryText
                                                    : Color.luxurySurface
                                                )
                                                .clipShape(Capsule())
                                                .overlay(Capsule()
                                                    .stroke(Color.luxuryDivider,
                                                            lineWidth: 0.5))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }

                                if linkSent {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color(hex: "#4A7C59"))
                                        Text("Link sent via \(channel == "whatsapp" ? "WhatsApp" : "SMS")")
                                            .font(BrandFont.body(12))
                                            .foregroundStyle(Color(hex: "#4A7C59"))
                                    }
                                }
                            }
                            .padding(.horizontal, Spacing.md)
                        }

                        if let error = vm.errorMessage {
                            ErrorBanner(message: error) {
                                vm.errorMessage = nil
                            }
                            .padding(.horizontal, Spacing.md)
                        }

                        // Initiate payment button
                        PrimaryButton(
                            title: vm.isLoading
                                ? "Initiating..."
                                : "Initiate Payment",
                            isLoading: vm.isLoading,
                            isDisabled: false
                        ) {
                            Task {
                                vm.currentPaymentLegIndex = legIndex
                                vm.currentPaymentItemIndex = itemIndex
                                await vm.initiateGatewayPaymentForItem(
                                    legIndex: legIndex,
                                    itemIndex: itemIndex,
                                    appointmentId: appointmentId
                                )
                                // ONLY dismiss if there was no error!
                                // Otherwise the user never sees the error message.
                                if vm.errorMessage == nil {
                                    if deliveryMode == "link" || deliveryMode == "both" {
                                        linkSent = true
                                    }
                                    dismiss()
                                }
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.bottom, Spacing.xl)
                    }
                    .padding(.vertical, Spacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("COLLECT PAYMENT")
                        .font(.system(size: 13, weight: .semibold))
                        .kerning(2)
                        .foregroundStyle(Color.luxuryPrimaryText)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.luxurySecondaryText)
                }
            }
            .onAppear {
                if deliveryMode.isEmpty {
                    deliveryMode = (item?.method ?? "") == "netbanking" ? "open" : "qr"
                }
            }
        }
    }
}
