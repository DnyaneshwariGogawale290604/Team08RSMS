import SwiftUI
import PostgREST
import Supabase

// MARK: - Appointment Detail Sheet
struct AppointmentDetailSheet: View {
    let appointment: Appointment
    @ObservedObject var vm: AppointmentsViewModel
    @EnvironmentObject var orderStore: SharedOrderStore
    @Environment(\.dismiss) var dismiss

    @State private var isStartingOrder = false
    @State private var checkoutVM: AssociateSalesViewModel? = nil
    @State private var showCheckout = false
    @State private var showCancelConfirm = false
    @State private var linkedOrderId: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.luxuryBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        clientHeader
                        detailCard
                        if let products = appointment.appointmentProducts, !products.isEmpty {
                            productsSection(products)
                        }
                        if let notes = appointment.notes, !notes.isEmpty {
                            notesSection(notes)
                        }
                        actionButtons
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 24)
                    .padding(.bottom, 40)
                }

                if isStartingOrder {
                    Color.luxuryBackground.opacity(0.85).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Preparing order…")
                            .font(BrandFont.body(13))
                            .foregroundStyle(Color.luxurySecondaryText)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("APPOINTMENT")
                        .font(.system(size: 13, weight: .semibold))
                        .kerning(2)
                        .foregroundStyle(Color.luxuryPrimaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.luxuryPrimaryText)
                }
            }
            .confirmationDialog("Are you sure?", isPresented: $showCancelConfirm, titleVisibility: .visible) {
                Button("Cancel Appointment", role: .destructive) {
                    Task {
                        await vm.updateStatus("cancelled", for: appointment.id)
                        dismiss()
                    }
                }
                Button("Keep", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $showCheckout) {
                if let cvm = checkoutVM {
                    SalesAssociateSalesView(
                        preConfiguredVM: cvm,
                        isModal: true,
                        appointmentId: appointment.id,
                        appointmentsVM: vm,
                        onComplete: {
                            showCheckout = false
                            // Mark appointment as completed → removes from appointment list,
                            // order now lives in the Orders tab.
                            Task { await vm.updateStatus("completed", for: appointment.id) }
                            dismiss()
                        }
                    )
                    .environmentObject(orderStore)
                }
            }
            .task {
                await fetchLinkedOrder()
            }
        }
    }

    // MARK: Sub-views
    private var clientHeader: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(Color(hex: "#C8913A").opacity(0.15))
                .frame(width: 72, height: 72)
                .overlay(
                    Text(String((appointment.customer?.name ?? "?").prefix(1)).uppercased())
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.luxuryPrimaryText)
                )
            Text(appointment.customer?.name ?? "Unknown Client")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(Color.luxuryPrimaryText)
            if let cat = appointment.customer?.customerCategory {
                Text(cat.uppercased())
                    .font(.system(size: 9, weight: .bold)).kerning(1)
                    .foregroundStyle(Color(hex: "#C8913A"))
                    .padding(.horizontal, 10).padding(.vertical, 4)
                    .background(Color(hex: "#C8913A").opacity(0.12))
                    .clipShape(Capsule())
            }
        }
    }

    private var detailCard: some View {
        VStack(spacing: 0) {
            detailRow(icon: "calendar", label: "Date & Time", value: appointment.displayDateTime)
            Divider().background(Color.luxuryDivider).padding(.leading, 44)
            detailRow(icon: "clock", label: "Duration", value: appointment.durationDisplay)
            if let phone = appointment.customer?.phone {
                Divider().background(Color.luxuryDivider).padding(.leading, 44)
                detailRow(icon: "phone", label: "Phone", value: phone)
            }
        }
        .background(Color.luxurySurface)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.luxuryDivider, lineWidth: 0.5))
    }

    private func productsSection(_ products: [AppointmentProductItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PRODUCTS OF INTEREST")
                .font(.system(size: 11, weight: .semibold)).kerning(1.2)
                .foregroundStyle(Color.luxurySecondaryText)
            VStack(spacing: 0) {
                ForEach(Array(products.enumerated()), id: \.element.id) { idx, item in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.luxuryBackground)
                            .frame(width: 36, height: 36)
                            .overlay(Image(systemName: "tag").font(.system(size: 13)).foregroundStyle(Color.luxurySecondaryText))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.product?.name ?? "Unknown product")
                                .font(BrandFont.body(14, weight: .medium))
                                .foregroundStyle(Color.luxuryPrimaryText)
                            if let notes = item.notes, !notes.isEmpty {
                                Text(notes).font(BrandFont.body(11)).foregroundStyle(Color.luxurySecondaryText)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("×\(item.quantity)")
                                .font(BrandFont.body(13, weight: .semibold))
                                .foregroundStyle(Color.luxuryPrimaryText)
                            if let price = item.product?.price {
                                Text("₹\(Int(price))")
                                    .font(BrandFont.body(11))
                                    .foregroundStyle(Color.luxurySecondaryText)
                            }
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    if idx < products.count - 1 {
                        Divider().background(Color.luxuryDivider).padding(.leading, 62)
                    }
                }
            }
            .background(Color.luxurySurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.luxuryDivider, lineWidth: 0.5))
        }
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES")
                .font(.system(size: 11, weight: .semibold)).kerning(1.2)
                .foregroundStyle(Color.luxurySecondaryText)
            Text(notes)
                .font(BrandFont.body(14))
                .foregroundStyle(Color.luxuryPrimaryText)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.luxurySurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.luxuryDivider, lineWidth: 0.5))
        }
    }

    private var hasProducts: Bool {
        !(appointment.appointmentProducts ?? []).isEmpty
    }

    private var actionButtons: some View {
        VStack(spacing: 10) {
            // Label: "Edit Order" if products were pre-selected, else "Start Order"
            Button {
                Task { await startOrder() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: hasProducts ? "pencil" : "cart.badge.plus")
                        .font(.system(size: 15, weight: .semibold))
                    Text(hasProducts ? "Edit Order" : "Start Order")
                        .font(BrandFont.body(15, weight: .semibold))
                }
                .foregroundStyle(Color.luxuryBackground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.luxuryPrimaryText)
                .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .disabled(isStartingOrder)

            // Cancel appointment
            Button { showCancelConfirm = true } label: {
                Text("Cancel Appointment")
                    .font(BrandFont.body(13))
                    .foregroundStyle(Color.luxurySecondaryText)
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.luxurySecondaryText)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.luxurySecondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.luxuryPrimaryText)
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
    }

    // MARK: - Start Order: fetch full data and launch checkout
    private func startOrder() async {
        isStartingOrder = true
        do {
            let customer = try await vm.fetchCustomer(id: appointment.customerId)
            let productIds = (appointment.appointmentProducts ?? []).compactMap { $0.product?.productId }
            let products = try await vm.fetchProducts(ids: productIds)

            // 1. Check if appointment has a linked order with existing billing legs
            if let orderId = linkedOrderId {
                let newVM = AssociateSalesViewModel()
                newVM.selectedCustomer = customer

                // Pre-fill cart
                for apptItem in appointment.appointmentProducts ?? [] {
                    guard let pId = apptItem.product?.productId,
                          let product = products.first(where: { $0.id == pId })
                    else { continue }
                    newVM.addToCart(product: product, quantity: apptItem.quantity)
                }

                // Set current order context
                newVM.currentOrder = SalesOrder(
                    id: UUID(uuidString: orderId) ?? UUID(),
                    customerId: appointment.customerId,
                    salesAssociateId: appointment.salesAssociateId,
                    storeId: appointment.storeId,
                    totalAmount: newVM.cartTotal,
                    status: nil,
                    createdAt: Date(),
                    ratingValue: nil,
                    ratingFeedback: nil
                )

                // Load existing legs from DB
                await newVM.loadExistingBillingLegs(salesOrderId: orderId)
                await newVM.fetchPaymentConfig()

                checkoutVM = newVM
                isStartingOrder = false
                // Open the Add Products screen; user taps billing button to proceed
                showCheckout = true
                return
            }

            // 2. Normal flow for new orders
            let newVM = AssociateSalesViewModel()
            newVM.selectedCustomer = customer

            // Pre-fill cart
            for apptItem in appointment.appointmentProducts ?? [] {
                guard let pId = apptItem.product?.productId,
                      let product = products.first(where: { $0.id == pId }) else { continue }
                newVM.addToCart(product: product, quantity: apptItem.quantity)
            }

            checkoutVM = newVM
            isStartingOrder = false
            showCheckout = true
        } catch {
            isStartingOrder = false
            vm.errorMessage = "Could not load order data: \(error.localizedDescription)"
        }
    }

    private func fetchLinkedOrder() async {
        do {
            struct OrderIdRow: Decodable { let order_id: UUID }
            let result: [OrderIdRow] = try await SupabaseManager.shared.client
                .from("sales_orders")
                .select("order_id")
                .eq("appointment_id", value: appointment.id.uuidString)
                .limit(1)
                .execute()
                .value
            if let first = result.first {
                self.linkedOrderId = first.order_id.uuidString
            }
        } catch {
            print("[fetchLinkedOrder] error: \(error)")
        }
    }
}
