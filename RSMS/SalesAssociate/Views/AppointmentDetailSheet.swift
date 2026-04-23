import SwiftUI

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

    var body: some View {
        NavigationStack {
            ZStack {
                Color.brandOffWhite.ignoresSafeArea()
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
                    Color.brandOffWhite.opacity(0.85).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Preparing order…")
                            .font(BrandFont.body(13))
                            .foregroundStyle(Color.brandWarmGrey)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("APPOINTMENT")
                        .font(.system(size: 13, weight: .semibold))
                        .kerning(2)
                        .foregroundStyle(Color.brandWarmBlack)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.brandWarmBlack)
                }
            }
            .confirmationDialog("Cancel Appointment", isPresented: $showCancelConfirm, titleVisibility: .visible) {
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
                            dismiss()
                        }
                    )
                    .environmentObject(orderStore)
                }
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
                        .foregroundStyle(Color.brandWarmBlack)
                )
            Text(appointment.customer?.name ?? "Unknown Client")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(Color.brandWarmBlack)
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
            Divider().background(Color.brandPebble).padding(.leading, 44)
            detailRow(icon: "clock", label: "Duration", value: appointment.durationDisplay)
            if let phone = appointment.customer?.phone {
                Divider().background(Color.brandPebble).padding(.leading, 44)
                detailRow(icon: "phone", label: "Phone", value: phone)
            }
        }
        .background(Color.brandLinen)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandPebble, lineWidth: 0.5))
    }

    private func productsSection(_ products: [AppointmentProductItem]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PRODUCTS OF INTEREST")
                .font(.system(size: 11, weight: .semibold)).kerning(1.2)
                .foregroundStyle(Color.brandWarmGrey)
            VStack(spacing: 0) {
                ForEach(Array(products.enumerated()), id: \.element.id) { idx, item in
                    HStack(spacing: 12) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.brandOffWhite)
                            .frame(width: 36, height: 36)
                            .overlay(Image(systemName: "tag").font(.system(size: 13)).foregroundStyle(Color.brandWarmGrey))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.product?.name ?? "Unknown product")
                                .font(BrandFont.body(14, weight: .medium))
                                .foregroundStyle(Color.brandWarmBlack)
                            if let notes = item.notes, !notes.isEmpty {
                                Text(notes).font(BrandFont.body(11)).foregroundStyle(Color.brandWarmGrey)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("×\(item.quantity)")
                                .font(BrandFont.body(13, weight: .semibold))
                                .foregroundStyle(Color.brandWarmBlack)
                            if let price = item.product?.price {
                                Text("₹\(Int(price))")
                                    .font(BrandFont.body(11))
                                    .foregroundStyle(Color.brandWarmGrey)
                            }
                        }
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    if idx < products.count - 1 {
                        Divider().background(Color.brandPebble).padding(.leading, 62)
                    }
                }
            }
            .background(Color.brandLinen)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.brandPebble, lineWidth: 0.5))
        }
    }

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES")
                .font(.system(size: 11, weight: .semibold)).kerning(1.2)
                .foregroundStyle(Color.brandWarmGrey)
            Text(notes)
                .font(BrandFont.body(14))
                .foregroundStyle(Color.brandWarmBlack)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.brandLinen)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.brandPebble, lineWidth: 0.5))
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
                .foregroundStyle(Color.brandOffWhite)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.brandWarmBlack)
                .clipShape(RoundedRectangle(cornerRadius: 13))
            }
            .disabled(isStartingOrder)

            // Cancel appointment
            Button { showCancelConfirm = true } label: {
                Text("Cancel Appointment")
                    .font(BrandFont.body(13))
                    .foregroundStyle(Color.brandWarmGrey)
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Color.brandWarmGrey)
                .frame(width: 20)
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Color.brandWarmGrey)
            Spacer()
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.brandWarmBlack)
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

            let newVM = AssociateSalesViewModel()
            newVM.selectedCustomer = customer

            // Pre-fill cart
            let apptItems = appointment.appointmentProducts ?? []
            for apptItem in apptItems {
                guard let pId = apptItem.product?.productId,
                      let product = products.first(where: { $0.id == pId }) else { continue }
                newVM.addToCart(product: product, quantity: apptItem.quantity)
            }

            checkoutVM = newVM
            isStartingOrder = false
            showCheckout = true

            // REMOVED: Prematurely marking as completed.
            // Marking as completed will now happen when user explicitly 'Saves' or 'Checkouts'.
        } catch {
            isStartingOrder = false
            vm.errorMessage = "Could not load order data: \(error.localizedDescription)"
        }
    }
}
