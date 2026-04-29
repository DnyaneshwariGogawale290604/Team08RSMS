import SwiftUI
import Combine
import Supabase
import PostgREST

// MARK: - SalesView (Tab Root)
struct SalesAssociateSalesView: View {
    @EnvironmentObject var orderStore: SharedOrderStore
    @StateObject private var vm: AssociateSalesViewModel
    @Environment(\.dismiss) private var dismiss

    /// Set when launched from an appointment to enable Save-back functionality
    private let appointmentId: UUID?
    private let isModal: Bool
    private let appointmentsVM: AppointmentsViewModel?
    private let onComplete: (() -> Void)?

    @State private var isSaving = false
    @State private var showSaveToast = false

    init(
        preConfiguredVM: AssociateSalesViewModel? = nil,
        isModal: Bool = false,
        appointmentId: UUID? = nil,
        appointmentsVM: AppointmentsViewModel? = nil,
        onComplete: (() -> Void)? = nil
    ) {
        _vm = StateObject(wrappedValue: preConfiguredVM ?? AssociateSalesViewModel())
        self.isModal = isModal
        self.appointmentId = appointmentId
        self.appointmentsVM = appointmentsVM
        self.onComplete = onComplete
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.luxuryBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        customerSection
                        if vm.selectedCustomer != nil {
                            cartSection
                            productRequestSection
                        }
                    }
                    .padding(.bottom, Spacing.xxl)
                }

                // Checkout / Save+Checkout FAB
                if !vm.cartItems.isEmpty {
                    VStack {
                        Spacer()
                        if isModal {
                            appointmentFABRow
                        } else {
                            checkoutFAB
                        }
                    }
                }

                // Cart toast overlay
                if vm.showCartToast, let name = vm.cartToastProduct {
                    VStack {
                        Spacer()
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.luxuryPrimary)
                                .font(.system(size: 16))
                            Text("\(name) added to cart")
                                .font(BrandFont.body(13, weight: .medium))
                                .foregroundStyle(Color.luxuryPrimaryText)
                            Spacer()
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: Radius.lg)
                                .fill(Color.luxurySurface)
                                .shadow(color: Color.black.opacity(0.08), radius: 12, y: 4)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.lg)
                                .stroke(Color.luxuryPrimary.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, Spacing.md)
                        .padding(.bottom, vm.cartItems.isEmpty ? Spacing.lg : 80)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75), value: vm.showCartToast)
                    .zIndex(10)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Back / Close button
                if isModal {
                    // Launched from appointment → dismiss the fullScreenCover
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(Color.luxuryPrimaryText)
                        }
                    }
                } else if vm.selectedCustomer != nil {
                    // Normal tab mode → clear customer/cart to go back to list
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                vm.clearCart()
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            .foregroundStyle(Color.luxuryPrimaryText)
                        }
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text(vm.selectedCustomer != nil ? vm.selectedCustomer!.name : "New Sale")
                        .font(.system(size: 13, weight: .semibold))
                        .kerning(1)
                        .foregroundStyle(Color.luxuryPrimaryText)
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .animation(.easeInOut, value: vm.selectedCustomer?.id)
                }
                
                if appointmentId != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            Task { await saveAppointmentChanges() }
                        } label: {
                            if isSaving {
                                ProgressView().tint(Color.luxuryBackground)
                            } else {
                                Text("Save")
                                    .font(.system(size: 13, weight: .semibold))
                                    .kerning(1)
                                    .foregroundStyle(Color.luxuryPrimaryText)
                            }
                        }
                        .disabled(isSaving)
                    }
                }
            }
            .sheet(isPresented: $vm.showCustomerSheet) { CustomerSheet(vm: vm) }
            .sheet(isPresented: $vm.showProductPicker) { ProductPickerSheet(vm: vm) }
            .sheet(isPresented: $vm.showBilling) {
                BillingView(
                    vm: vm,
                    appointmentId: appointmentId,
                    appointmentsVM: appointmentsVM,
                    maxLegs: vm.maxPaymentLegs,
                    maxSplits: vm.maxLegSplits
                )
                .environmentObject(orderStore)
            }
            .sheet(isPresented: $vm.showReceipt) {
                ReceiptSheet(vm: vm, onComplete: onComplete)
                    .environmentObject(orderStore)
            }
            .sheet(isPresented: $vm.showProductRequest) { ProductRequestSheet(vm: vm) }
            .alert("Success", isPresented: Binding(
                get: { vm.successMessage != nil },
                set: { if !$0 { vm.successMessage = nil } }
            )) {
                Button("OK") { vm.successMessage = nil }
            } message: { Text(vm.successMessage ?? "") }
            .onAppear {
                if isModal && vm.currentOrder == nil {
                    // Fresh appointment checkout - ensure no stale billing data
                    vm.resetOrderContext()
                }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: NSNotification.Name("OpenRazorpayCheckout")
            )) { _ in
                vm.openRazorpayCheckout()
            }
            .onReceive(NotificationCenter.default.publisher(
                for: NSNotification.Name("OpenCashfreeCheckout")
            )) { _ in
                vm.openCashfreeCheckout()
            }
            .onReceive(NotificationCenter.default.publisher(
                for: NSNotification.Name("OpenPayUCheckout")
            )) { _ in
                vm.openPayUCheckout()
            }
        }
        .task { await vm.fetchCustomers() }
    }

    // MARK: - Customer section
    private var customerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                SectionHeader(title: "Customer")
                Spacer()
                // Only show + when no customer is selected;
                // the "Change" button inside the card handles switching.
                if vm.selectedCustomer == nil {
                    Button { vm.showCustomerSheet = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.luxuryPrimaryText)
                    }
                    .padding(.trailing, Spacing.md)
                }
            }

            if let customer = vm.selectedCustomer {
                HStack(spacing: Spacing.md) {
                    Circle()
                        .fill(Color.luxuryDivider.opacity(0.4))
                        .frame(width: 44, height: 44)
                        .overlay(
                            Text(String(customer.name.prefix(1)).uppercased())
                                .font(.system(size: 18, weight: .semibold, design: .serif))
                                .foregroundStyle(Color.luxuryPrimaryText)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(customer.name)
                            .font(BrandFont.body(15, weight: .semibold))
                            .foregroundStyle(Color.luxuryPrimaryText)
                        if let phone = customer.phone {
                            Text(phone).font(BrandFont.body(12)).foregroundStyle(Color.luxurySecondaryText)
                        }
                    }
                    Spacer()
                    if let cat = customer.customerCategory {
                        BadgeView(text: cat, color: cat == "VIP" ? Color(hex: "#C8913A") : Color.luxurySecondaryText)
                    }
                    Button { vm.showCustomerSheet = true } label: {
                        Text("Change").font(BrandFont.body(13)).foregroundStyle(Color.luxurySecondaryText)
                    }
                }
                .padding(Spacing.md)
                .background(Color.luxurySurface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.luxuryDivider, lineWidth: 0.5))
                .padding(.horizontal, Spacing.md)
            } else {
                if vm.customers.isEmpty {
                    HStack {
                        Image(systemName: "person.badge.plus").foregroundStyle(Color.luxurySecondaryText)
                        Text("No customers yet. Tap + to add one.")
                            .font(BrandFont.body(13)).foregroundStyle(Color.luxurySecondaryText)
                    }
                    .padding(Spacing.md).frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.luxurySurface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                    .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.luxuryDivider, lineWidth: 0.5))
                    .padding(.horizontal, Spacing.md)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(vm.customers.prefix(8).enumerated()), id: \.element.id) { index, customer in
                            Button { vm.selectedCustomer = customer } label: {
                                HStack(spacing: Spacing.md) {
                                    Circle()
                                        .fill(Color.luxuryDivider.opacity(0.3)).frame(width: 38, height: 38)
                                        .overlay(
                                            Text(String(customer.name.prefix(1)).uppercased())
                                                .font(.system(size: 15, weight: .medium, design: .serif))
                                                .foregroundStyle(Color.luxuryPrimaryText)
                                        )
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(customer.name).font(BrandFont.body(14, weight: .medium)).foregroundStyle(Color.luxuryPrimaryText)
                                        if let phone = customer.phone { Text(phone).font(BrandFont.body(11)).foregroundStyle(Color.luxurySecondaryText) }
                                    }
                                    Spacer()
                                    if let cat = customer.customerCategory {
                                        BadgeView(text: cat, color: cat == "VIP" ? Color(hex: "#C8913A") : Color.luxurySecondaryText)
                                    }
                                    Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Color.luxuryDivider)
                                }
                                .padding(.horizontal, Spacing.md).padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)
                            if index < vm.customers.prefix(8).count - 1 { BrandDivider().padding(.leading, Spacing.md) }
                        }
                    }
                    .background(Color.luxurySurface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                    .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.luxuryDivider, lineWidth: 0.5))
                    .padding(.horizontal, Spacing.md)
                }
            }
        }
        .padding(.top, Spacing.md)
    }

    // MARK: - Cart section
    private var cartSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(title: "Cart (\(vm.cartCount) items)")
            if vm.cartItems.isEmpty {
                Button {
                    Task { await vm.fetchProducts() }
                    vm.showProductPicker = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle").foregroundStyle(Color.luxurySecondaryText)
                        Text("Add products to cart").font(BrandFont.body(14)).foregroundStyle(Color.luxurySecondaryText)
                        Spacer()
                        Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Color.luxuryDivider)
                    }
                    .padding(Spacing.md).background(Color.luxurySurface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                    .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.luxuryDivider, lineWidth: 0.5))
                }
                .buttonStyle(.plain).padding(.horizontal, Spacing.md)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(vm.cartItems.enumerated()), id: \.element.id) { index, item in
                        CartItemRow(item: item, vm: vm)
                        if index < vm.cartItems.count - 1 { BrandDivider().padding(.leading, Spacing.md) }
                    }
                    BrandDivider()
                    Button {
                        Task { await vm.fetchProducts() }
                        vm.showProductPicker = true
                    } label: {
                        HStack {
                            Image(systemName: "plus").font(.system(size: 12))
                            Text("Add more products").font(BrandFont.body(13))
                        }
                        .foregroundStyle(Color.luxurySecondaryText).padding(Spacing.md)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    BrandDivider()
                    HStack {
                        Text("Total").font(BrandFont.body(15, weight: .semibold)).foregroundStyle(Color.luxuryPrimaryText)
                        Spacer()
                        Text("₹\(formatINR(vm.cartTotal))").font(.system(size: 20, weight: .semibold, design: .serif)).foregroundStyle(Color.luxuryDeepAccent)
                    }.padding(Spacing.md)
                }
                .background(Color.luxurySurface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.luxuryDivider, lineWidth: 0.5))
                .padding(.horizontal, Spacing.md)
            }
            if let err = vm.errorMessage { ErrorBanner(message: err) { vm.errorMessage = nil } }
        }
    }

    // MARK: - Product request
    private var productRequestSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            SectionHeader(title: "Inactive?")
            Button {
                Task { await vm.fetchProducts() }
                vm.showProductRequest = true
            } label: {
                HStack {
                    Image(systemName: "arrow.up.circle").foregroundStyle(Color.luxurySecondaryText)
                    Text("Raise request to manager").font(BrandFont.body(14)).foregroundStyle(Color.luxuryPrimaryText)
                    Spacer()
                    Image(systemName: "chevron.right").font(.system(size: 11)).foregroundStyle(Color.luxuryDivider)
                }
                .padding(Spacing.md).background(Color.luxurySurface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.luxuryDivider, lineWidth: 0.5))
            }
            .buttonStyle(.plain).padding(.horizontal, Spacing.md)
        }
    }

    // MARK: - Checkout FAB
    // MARK: - Normal checkout FAB
    private var checkoutFAB: some View {
        Button {
            Task { await beginCheckout() }
        } label: {
            HStack(spacing: Spacing.md) {
                if vm.isLoading {
                    ProgressView().tint(Color.white).scaleEffect(0.85)
                } else {
                    Image(systemName: "creditcard").font(.system(size: 15))
                }
                Text(vm.isLoading ? "Placing order..." : "Checkout — ₹\(formatINR(vm.cartTotal))")
                    .font(BrandFont.body(15, weight: .semibold))
            }
            .foregroundStyle(Color.white)
            .padding(.horizontal, Spacing.lg)
            .frame(height: 54)
            .background(Color.luxuryDeepAccent)
            .clipShape(Capsule())
            .shadow(color: Color.luxuryDeepAccent.opacity(0.30), radius: 12, y: 4)
        }
        .padding(.bottom, Spacing.lg)
        .disabled(vm.isLoading)
    }

    // MARK: - Appointment mode: Save + Checkout side-by-side
    private var appointmentFABRow: some View {
        HStack {
            // Billing — opens the billing configuration screen
            Button {
                Task { await beginCheckout() }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "creditcard.fill").font(.system(size: 16))
                    Text("Billing")
                        .font(BrandFont.body(16, weight: .bold))
                }
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Color.luxuryDeepAccent)
                .clipShape(Capsule())
                .shadow(color: Color.luxuryDeepAccent.opacity(0.20), radius: 10, y: 5)
            }
            .padding(.horizontal, Spacing.md)
        }
        .padding(.bottom, 20)
    }

    // MARK: - Save appointment product changes back to Supabase
    private func saveAppointmentChanges() async {
        guard let apptId = appointmentId, let avm = appointmentsVM else {
            print("[Save] Missing appointmentId or appointmentsVM — cannot save")
            return
        }
        isSaving = true

        do {
            // 1. Delete all existing products for this appointment
            try await SupabaseManager.shared.client
                .from("appointment_products")
                .delete()
                .eq("appointment_id", value: apptId.uuidString)
                .execute()

            // 2. Re-insert the current cart as new appointment_products
            if !vm.cartItems.isEmpty {
                struct APInsert: Encodable {
                    let appointment_id: UUID
                    let product_id: UUID
                    let quantity: Int
                    let notes: String?
                }
                let items = vm.cartItems.map {
                    APInsert(appointment_id: apptId,
                             product_id: $0.product.id,
                             quantity: $0.quantity,
                             notes: nil)
                }
                try await SupabaseManager.shared.client
                    .from("appointment_products")
                    .insert(items)
                    .execute()
            }

            // 3. Refresh appointments list so the card reflects the new products
            await avm.fetchAppointments()

            isSaving = false
            // 5. Close both the checkout screen and the parent appointment detail
            if let onComplete = onComplete {
                onComplete()
            } else {
                dismiss()
            }
        } catch {
            isSaving = false
            vm.errorMessage = "Failed to save changes: \(error.localizedDescription)"
            print("[Save] Error: \(error)")
        }
    }

    private func beginCheckout() async {
        // If order already exists (loaded from appointment)
        // go straight to billing, but update it first if cart changed
        if vm.currentOrder != nil {
            await vm.syncOrderWithCart(appointmentId: appointmentId)
            await vm.fetchPaymentConfig()
            vm.showBilling = true
            return
        }

        // Otherwise place order first
        await vm.placeOrder(
            orderStore: orderStore,
            appointmentId: appointmentId,
            appointmentsVM: appointmentsVM
        )

        guard vm.currentOrder != nil,
              vm.errorMessage == nil else { return }

        await vm.fetchPaymentConfig()
        vm.showBilling = true
    }

    private func formatINR(_ v: Double) -> String {
        let f = NumberFormatter(); f.numberStyle = .decimal; f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "\(Int(v))"
    }
}

// MARK: - CartItemRow
struct CartItemRow: View {
    let item: CartItem
    @ObservedObject var vm: AssociateSalesViewModel
    var body: some View {
        HStack(spacing: Spacing.md) {
            VStack(alignment: .leading, spacing: 3) {
                Text(item.product.name).font(BrandFont.body(14, weight: .medium)).foregroundStyle(Color.luxuryPrimaryText)
                if let size = item.selectedSize { Text("Size: \(size)").font(BrandFont.body(11)).foregroundStyle(Color.luxurySecondaryText) }
                Text("₹\(Int(item.product.price)) each").font(BrandFont.body(11)).foregroundStyle(Color.luxuryMutedText)
            }
            Spacer()
            HStack(spacing: 10) {
                Button { vm.updateQuantity(item: item, quantity: item.quantity - 1) } label: {
                    Image(systemName: item.quantity <= 1 ? "trash" : "minus")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(item.quantity <= 1 ? Color(hex: "#9B4444") : Color.luxurySecondaryText)
                        .frame(width: 28, height: 28).background(Color.luxurySurface).clipShape(Circle())
                }
                Text("\(item.quantity)").font(BrandFont.body(14, weight: .semibold)).foregroundStyle(Color.luxuryPrimaryText).frame(minWidth: 20)
                Button { vm.updateQuantity(item: item, quantity: item.quantity + 1) } label: {
                    Image(systemName: "plus").font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.luxuryPrimaryText)
                        .frame(width: 28, height: 28).background(Color.luxurySurface).clipShape(Circle())
                }
            }
            Text("₹\(Int(item.lineTotal))").font(BrandFont.body(14, weight: .semibold)).foregroundStyle(Color.luxuryDeepAccent).frame(minWidth: 55, alignment: .trailing)
        }
        .padding(.horizontal, Spacing.md).padding(.vertical, 14)
    }
}

// MARK: - CustomerSheet
struct CustomerSheet: View {
    @ObservedObject var vm: AssociateSalesViewModel
    @Environment(\.dismiss) var dismiss
    @State private var mode: SheetMode
    @State private var searchText = ""
    @State private var name = ""; @State private var phone = ""; @State private var email = ""
    @State private var gender = ""; @State private var dob = ""; @State private var address = ""
    @State private var nationality = ""; @State private var notes = ""; @State private var category = "Regular"

    enum SheetMode { case list, create }

    init(vm: AssociateSalesViewModel, initialMode: SheetMode = .list) {
        self.vm = vm
        _mode = State(initialValue: initialMode)
    }

    var filteredCustomers: [Customer] {
        searchText.isEmpty ? vm.customers : vm.customers.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) || ($0.phone?.contains(searchText) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.luxuryBackground.ignoresSafeArea()
                if mode == .list { listView } else { createView }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(mode == .list ? "SELECT CUSTOMER" : "NEW CUSTOMER")
                        .font(.system(size: 13, weight: .semibold)).kerning(2).foregroundStyle(Color.luxuryPrimaryText)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button(mode == .list ? "Done" : "Back") {
                        if mode == .create { withAnimation { mode = .list } } else { dismiss() }
                    }.font(BrandFont.body(14)).foregroundStyle(Color.luxuryPrimaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if mode == .list {
                        Button { withAnimation { mode = .create } } label: {
                            Image(systemName: "plus.circle.fill").font(.system(size: 22)).foregroundStyle(Color.luxuryPrimaryText)
                        }
                    }
                }
            }
        }
    }

    private var listView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.luxurySecondaryText).font(.system(size: 14))
                TextField("Search by name or phone...", text: $searchText).font(BrandFont.body(14))
            }
            .padding(Spacing.md).background(Color.luxurySurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color.luxuryDivider, lineWidth: 0.5))
            .padding(Spacing.md)

            if filteredCustomers.isEmpty {
                EmptyStateView(icon: "person.slash", title: "No customers", message: "Tap + to create a new customer.")
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        ForEach(Array(filteredCustomers.enumerated()), id: \.element.id) { index, customer in
                            Button { vm.selectedCustomer = customer; dismiss() } label: {
                                HStack(spacing: Spacing.md) {
                                    Circle().fill(Color.luxurySurface).frame(width: 40, height: 40)
                                        .overlay(Text(String(customer.name.prefix(1)).uppercased()).font(.system(size: 16, weight: .medium, design: .serif)).foregroundStyle(Color.luxuryPrimaryText))
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(customer.name).font(BrandFont.body(15, weight: .medium)).foregroundStyle(Color.luxuryPrimaryText)
                                        HStack(spacing: 6) {
                                            if let ph = customer.phone { Text(ph).font(BrandFont.body(12)).foregroundStyle(Color.luxurySecondaryText) }
                                            if let em = customer.email { Text(em).font(BrandFont.body(12)).foregroundStyle(Color.luxurySecondaryText) }
                                        }
                                    }
                                    Spacer()
                                    if let cat = customer.customerCategory { BadgeView(text: cat, color: cat == "VIP" ? Color(hex: "#C8913A") : Color.luxurySecondaryText) }
                                    if vm.selectedCustomer?.id == customer.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.luxuryPrimary) }
                                }
                                .padding(.horizontal, Spacing.md).padding(.vertical, 14)
                            }
                            .buttonStyle(.plain)
                            if index < filteredCustomers.count - 1 { BrandDivider().padding(.leading, Spacing.md) }
                        }
                    }
                    .background(Color.luxurySurface).clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                    .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.luxuryDivider, lineWidth: 0.5))
                    .padding(.horizontal, Spacing.md)
                }
            }
        }
    }

    private var createView: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: Spacing.md) {
                formSection(title: "Required") { brandField("Full Name *", text: $name, icon: "person") }
                formSection(title: "Contact") {
                    brandField("Phone Number", text: $phone, icon: "phone", keyboard: .phonePad)
                    BrandDivider().padding(.leading, Spacing.md)
                    brandField("Email Address", text: $email, icon: "envelope", keyboard: .emailAddress, autocap: TextInputAutocapitalization.never)
                }
                formSection(title: "Personal Details") {
                    genderPicker
                    BrandDivider().padding(.leading, Spacing.md)
                    brandField("Date of Birth (YYYY-MM-DD)", text: $dob, icon: "calendar")
                    BrandDivider().padding(.leading, Spacing.md)
                    brandField("Nationality", text: $nationality, icon: "globe")
                }
                formSection(title: "Address") { brandField("Address", text: $address, icon: "location", multiline: true) }
                formSection(title: "Customer Category") { categoryPicker }
                formSection(title: "Notes") { brandField("Internal notes...", text: $notes, icon: "note.text", multiline: true) }
                if let err = vm.errorMessage { ErrorBanner(message: err) { vm.errorMessage = nil } }
                PrimaryButton(title: "Create Customer", isLoading: vm.isLoading, isDisabled: name.trimmingCharacters(in: .whitespaces).isEmpty) {
                    Task {
                        let success = await vm.createCustomer(name: name, phone: phone, email: email,
                            gender: gender.isEmpty ? nil : gender, dateOfBirth: dob.isEmpty ? nil : dob,
                            address: address.isEmpty ? nil : address, nationality: nationality.isEmpty ? nil : nationality,
                            notes: notes.isEmpty ? nil : notes, category: category)
                        if success { dismiss() }
                    }
                }
                .padding(.horizontal, Spacing.md).padding(.top, Spacing.sm).padding(.bottom, Spacing.xl)
            }
            .padding(.top, Spacing.md)
        }
    }

    @ViewBuilder
    private func formSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title.uppercased()).font(.system(size: 10, weight: .semibold)).kerning(1.2).foregroundStyle(Color.luxurySecondaryText).padding(.horizontal, Spacing.md)
            VStack(spacing: 0) { content() }.background(Color.luxurySurface).clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.luxuryDivider, lineWidth: 0.5)).padding(.horizontal, Spacing.md)
        }
    }

    private func brandField(_ placeholder: String, text: Binding<String>, icon: String, keyboard: UIKeyboardType = .default, autocap: TextInputAutocapitalization = .words, multiline: Bool = false) -> some View {
        HStack(alignment: multiline ? .top : .center, spacing: Spacing.sm) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(Color.luxurySecondaryText).frame(width: 20).padding(.top, multiline ? 2 : 0)
            if multiline { TextField(placeholder, text: text, axis: .vertical).lineLimit(3...5).font(BrandFont.body(14)).foregroundStyle(Color.luxuryPrimaryText) }
            else { TextField(placeholder, text: text).keyboardType(keyboard).textInputAutocapitalization(autocap).autocorrectionDisabled().font(BrandFont.body(14)).foregroundStyle(Color.luxuryPrimaryText) }
        }.padding(Spacing.md)
    }

    private var genderPicker: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "person.fill").font(.system(size: 14)).foregroundStyle(Color.luxurySecondaryText).frame(width: 20)
            Text("Gender").font(BrandFont.body(14)).foregroundStyle(gender.isEmpty ? Color.luxuryDivider : Color.luxuryPrimaryText)
            Spacer()
            Picker("", selection: $gender) {
                Text("Not specified").tag(""); Text("Male").tag("Male"); Text("Female").tag("Female"); Text("Other").tag("Other")
            }.pickerStyle(.menu).tint(Color.luxuryPrimaryText)
        }.padding(Spacing.md)
    }

    private var categoryPicker: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "star").font(.system(size: 14)).foregroundStyle(Color.luxurySecondaryText).frame(width: 20)
            Text("Category").font(BrandFont.body(14)).foregroundStyle(Color.luxuryPrimaryText)
            Spacer()
            Picker("", selection: $category) { Text("Regular").tag("Regular"); Text("VIP").tag("VIP") }
                .pickerStyle(.segmented).frame(width: 160)
        }.padding(Spacing.md)
    }
}

// MARK: - ProductPickerSheet
struct ProductPickerSheet: View {
    @ObservedObject var vm: AssociateSalesViewModel
    @Environment(\.dismiss) var dismiss
    @State private var sizeSelection: [UUID: String] = [:]
    @State private var addedProducts: Set<UUID> = []

    var body: some View {
        NavigationStack {
            ZStack {
                Color.luxuryBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.luxurySecondaryText).font(.system(size: 14))
                        TextField("Search products...", text: $vm.productSearch).font(BrandFont.body(14))
                            .onChange(of: vm.productSearch) { new in Task { await vm.fetchProducts(search: new) } }
                    }
                    .padding(Spacing.md).background(Color.luxurySurface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color.luxuryDivider, lineWidth: 0.5))
                    .padding(Spacing.md)

                    if vm.products.isEmpty {
                        EmptyStateView(icon: "tag.slash", title: "No products", message: "Try a different search.")
                    } else {
                        if let diagnostic = vm.recommendationDiagnosticMessage,
                           vm.recommendedProducts.isEmpty,
                           !vm.cartItems.isEmpty {
                            Text(diagnostic)
                                .font(BrandFont.body(12))
                                .foregroundStyle(Color.luxurySecondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, Spacing.md)
                                .padding(.bottom, Spacing.sm)
                        }
                        ScrollView(showsIndicators: false) {
                            VStack(spacing: Spacing.md) { ForEach(vm.products) { productCard($0) } }
                                .padding(.horizontal, Spacing.md).padding(.bottom, Spacing.xl)
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Text("ADD PRODUCTS").font(.system(size: 13, weight: .semibold)).kerning(2).foregroundStyle(Color.luxuryPrimaryText) }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.font(BrandFont.body(14, weight: .semibold)).foregroundStyle(Color.luxuryPrimaryText) }
            }
        }
    }

    private func productCard(_ product: Product) -> some View {
        let isAdded = addedProducts.contains(product.id)
        let isRecommended = vm.recommendedProducts.contains(where: { $0.id == product.id })
        
        return VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(product.name).font(BrandFont.body(15, weight: .medium)).foregroundStyle(Color.luxuryPrimaryText)
                    Text(product.category).font(BrandFont.body(12)).foregroundStyle(Color.luxurySecondaryText)
                    
                    if isRecommended {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                            Text("AI Recommended")
                        }
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: "#6E5155"))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color(hex: "#6E5155").opacity(0.1))
                        .clipShape(Capsule())
                        .padding(.top, 2)
                    }
                }
                Spacer()
                Text("₹\(Int(product.price))").font(.system(size: 17, weight: .semibold, design: .serif)).foregroundStyle(Color.luxuryPrimaryText)
            }
            Button {
                vm.addToCart(product: product, size: nil)
                withAnimation(.easeInOut(duration: 0.2)) { addedProducts.insert(product.id) }
                Task { try? await Task.sleep(nanoseconds: 1_500_000_000); withAnimation { addedProducts.remove(product.id) } }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isAdded ? "checkmark" : "plus").font(.system(size: 11, weight: .semibold))
                    Text(isAdded ? "Added!" : "Add to Cart").font(BrandFont.body(13, weight: .medium))
                }
                .foregroundStyle(isAdded ? Color.luxuryPrimary : Color.white)
                .padding(.horizontal, Spacing.md).padding(.vertical, 8)
                .background(isAdded ? Color.luxuryPrimary.opacity(0.12) : Color.luxuryDeepAccent)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(isAdded ? Color.luxuryPrimary.opacity(0.4) : Color.clear, lineWidth: 1))
            }
            .buttonStyle(.plain).animation(.easeInOut(duration: 0.2), value: isAdded)
        }
        .padding(Spacing.md).background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - PaymentSheet
struct PaymentSheet: View {
    @ObservedObject var vm: AssociateSalesViewModel
    @Environment(\.dismiss) var dismiss
    @State private var upiMode = "qr"
    @State private var upiPhoneNumber = ""
    @State private var upiChannel = "whatsapp"
    @State private var upiLinkSent = false
    @State private var netbankingMode = "qr"
    @State private var netbankingPhoneNumber = ""
    @State private var netbankingChannel = "whatsapp"
    @State private var netbankingDeliveryPrepared = false

    private var availableMethods: [(String, String, String)] {
        let allMethods: [(String, String, String)] = [
            ("upi", "qrcode", "UPI"),
            ("cash", "banknote", "Cash"),
            ("netbanking", "building.columns", "Net Banking")
        ]
        return allMethods.filter { method in
            vm.enabledPaymentMethods.contains(method.0)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.luxuryBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.lg) {
                        // Gateway config loading state
                        if vm.isLoadingGatewayConfig {
                            HStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(0.85)
                                Text("Loading payment options...")
                                    .font(BrandFont.body(13))
                                    .foregroundStyle(Color.luxurySecondaryText)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(Spacing.md)
                            .background(Color.luxurySurface)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            .overlay(RoundedRectangle(cornerRadius: Radius.md)
                                .stroke(Color.luxuryDivider, lineWidth: 0.5))
                            .padding(.horizontal, Spacing.md)
                        }

                        // Not configured warning — only show if UPI or netbanking
                        // was expected but gateway is not set up
                        if !vm.gatewayConfigured && !vm.isLoadingGatewayConfig {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(Color(hex: "#C8913A"))
                                    .font(.system(size: 14))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("No payment gateway configured")
                                        .font(BrandFont.body(13, weight: .semibold))
                                        .foregroundStyle(Color.luxuryPrimaryText)
                                    Text("Contact your admin to set up UPI or Net Banking.")
                                        .font(BrandFont.body(12))
                                        .foregroundStyle(Color.luxurySecondaryText)
                                }
                                Spacer()
                            }
                            .padding(Spacing.md)
                            .background(Color(hex: "#C8913A").opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            .overlay(RoundedRectangle(cornerRadius: Radius.md)
                                .stroke(Color(hex: "#C8913A").opacity(0.3), lineWidth: 0.5))
                            .padding(.horizontal, Spacing.md)
                        }

                        orderSummary
                        paymentMethods
                        paymentContent
                        if let err = vm.errorMessage {
                            ErrorBanner(message: err) { vm.errorMessage = nil }
                        }
                    }
                    .padding(.vertical, Spacing.lg)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("PAYMENT")
                        .font(.system(size: 13, weight: .semibold))
                        .kerning(2)
                        .foregroundStyle(Color.luxuryPrimaryText)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.luxurySecondaryText)
                }
            }
            .task {
                await vm.fetchPaymentConfig()
            }
        }
    }

    private var amountDue: Double {
        vm.currentOrder?.totalAmount ?? vm.cartTotal
    }

    private var cashChange: Double {
        vm.cashTendered - amountDue
    }

    private var cashTenderedText: Binding<String> {
        Binding(
            get: {
                guard vm.cashTendered > 0 else { return "" }
                if vm.cashTendered.rounded(.towardZero) == vm.cashTendered {
                    return String(Int(vm.cashTendered))
                }
                return String(format: "%.2f", vm.cashTendered)
            },
            set: { newValue in
                let filtered = newValue.filter { "0123456789.".contains($0) }
                vm.cashTendered = Double(filtered) ?? 0
            }
        )
    }

    private var orderSummary: some View {
        VStack(spacing: 0) {
            ForEach(Array(vm.cartItems.enumerated()), id: \.element.id) { index, item in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.product.name).font(BrandFont.body(14)).foregroundStyle(Color.luxuryPrimaryText)
                        if let sz = item.selectedSize { Text("Size \(sz)").font(BrandFont.body(11)).foregroundStyle(Color.luxurySecondaryText) }
                    }
                    Spacer()
                    Text("×\(item.quantity)").font(BrandFont.body(12)).foregroundStyle(Color.luxurySecondaryText)
                    Text("₹\(Int(item.lineTotal))").font(BrandFont.body(14, weight: .medium)).foregroundStyle(Color.luxuryPrimaryText)
                }
                .padding(.horizontal, Spacing.md).padding(.vertical, 12)
                if index < vm.cartItems.count - 1 { BrandDivider().padding(.leading, Spacing.md) }
            }
            BrandDivider()
            HStack {
                Text("Total").font(BrandFont.body(15, weight: .semibold)).foregroundStyle(Color.luxuryPrimaryText)
                Spacer()
                Text("₹\(Int(amountDue))").font(.system(size: 22, weight: .semibold, design: .serif)).foregroundStyle(Color.luxuryDeepAccent)
            }
            .padding(Spacing.md)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
        .padding(.horizontal, Spacing.md)
    }

    private var paymentMethods: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("PAYMENT METHOD")
                .font(.system(size: 10, weight: .semibold))
                .kerning(1.2)
                .foregroundStyle(Color.luxurySecondaryText)
                .padding(.horizontal, Spacing.md)

            if vm.gatewayConfigured {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color.luxuryPrimary)
                        .frame(width: 6, height: 6)
                    Text(vm.activeGateway.capitalized + " connected")
                        .font(BrandFont.body(11))
                        .foregroundStyle(Color.luxuryPrimary)
                }
                .padding(.horizontal, Spacing.md)
            }

            HStack(spacing: Spacing.sm) {
                ForEach(availableMethods, id: \.0) { method in
                    methodButton(id: method.0, icon: method.1, title: method.2)
                }
            }
            .padding(.horizontal, Spacing.md)
        }
    }

    @ViewBuilder
    private var paymentContent: some View {
        switch vm.paymentMethod {
        case "cash":
            cashView
        case "netbanking":
            netBankingView
        default:
            upiView
        }
    }

    private var upiView: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionTitle("UPI FLOW")
            deliveryModeSelector(
                selection: $upiMode,
                options: [("qr", "Show QR"), ("link", "Share Link"), ("both", "Both")]
            )

            if upiMode == "qr" || upiMode == "both" {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    qrPlaceholder(title: "QR will appear here", footer: "yourshop@upi")
                    appPills(["GPay", "PhonePe", "Paytm", "BHIM"])
                }
            }

            if upiMode == "link" || upiMode == "both" {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    phoneField(title: "Phone Number", text: $upiPhoneNumber)
                    channelSelector(selection: $upiChannel)

                    Button {
                        upiLinkSent = !upiPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    } label: {
                        HStack {
                            Image(systemName: upiChannel == "whatsapp" ? "message.badge" : "message")
                            Text("Send Link")
                                .font(BrandFont.body(14, weight: .medium))
                        }
                        .foregroundStyle(Color.luxuryPrimaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.luxurySurface)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color.luxuryDivider, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)

                    if upiLinkSent {
                        statusBox(
                            title: "Payment link ready",
                            message: "Share the payment link with the customer on \(upiChannel == "whatsapp" ? "WhatsApp" : "SMS")."
                        )
                    }
                }
            }

            PrimaryButton(title: "Customer has paid — Confirm", isLoading: vm.isLoading) {
                Task { await vm.processPayment(method: "upi") }
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    private var cashView: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionTitle("CASH")
            amountCard(label: "Amount Due", value: "₹\(formatAmount(amountDue))")

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("QUICK ADD")
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(1.2)
                    .foregroundStyle(Color.luxurySecondaryText)

                HStack(spacing: Spacing.sm) {
                    cashChip(title: "+₹500") { vm.cashTendered += 500 }
                    cashChip(title: "+₹1000") { vm.cashTendered += 1000 }
                    cashChip(title: "+₹2000") { vm.cashTendered += 2000 }
                    cashChip(title: "Exact") { vm.cashTendered = amountDue }
                }
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("TENDERED AMOUNT")
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(1.2)
                    .foregroundStyle(Color.luxurySecondaryText)

                TextField("Enter amount received", text: cashTenderedText)
                    .keyboardType(.decimalPad)
                    .font(BrandFont.body(15))
                    .padding(Spacing.md)
                    .background(Color.luxurySurface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color.luxuryDivider, lineWidth: 0.5))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(cashChange >= 0 ? "Change" : "Short")
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(1.2)
                    .foregroundStyle(Color.luxurySecondaryText)
                Text("₹\(formatAmount(abs(cashChange)))")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(cashChange >= 0 ? Color.luxuryDeepAccent : Color(hex: "#9B4444"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(Color.luxurySurface)
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.luxuryDivider, lineWidth: 0.5))

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("NOTE (OPTIONAL)")
                    .font(.system(size: 10, weight: .semibold))
                    .kerning(1.2)
                    .foregroundStyle(Color.luxurySecondaryText)
                TextField("Cash note...", text: $vm.cashNote, axis: .vertical)
                    .lineLimit(2...4)
                    .font(BrandFont.body(14))
                    .padding(Spacing.md)
                    .background(Color.luxurySurface)
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color.luxuryDivider, lineWidth: 0.5))
            }

            PrimaryButton(
                title: "Save & Confirm",
                isLoading: vm.isLoading,
                isDisabled: vm.cashTendered < amountDue
            ) {
                Task { await vm.processPayment(method: "cash") }
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    private var netBankingView: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            sectionTitle("NET BANKING")
            deliveryModeSelector(
                selection: $netbankingMode,
                options: [("qr", "Scan QR"), ("link", "Send Link"), ("both", "Both")]
            )

            if netbankingMode == "qr" || netbankingMode == "both" {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    qrPlaceholder(title: "QR will appear here", footer: "Scan with your bank app")
                    Button {
                        netbankingDeliveryPrepared = true
                    } label: {
                        Text("Prepare QR")
                            .font(BrandFont.body(14, weight: .medium))
                            .foregroundStyle(Color.luxuryPrimaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.luxurySurface)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color.luxuryDivider, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }

            if netbankingMode == "link" || netbankingMode == "both" {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    phoneField(title: "Phone Number", text: $netbankingPhoneNumber)
                    channelSelector(selection: $netbankingChannel)

                    Button {
                        netbankingDeliveryPrepared = !netbankingPhoneNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    } label: {
                        HStack {
                            Image(systemName: netbankingChannel == "whatsapp" ? "message.badge" : "message")
                            Text("Generate Link")
                                .font(BrandFont.body(14, weight: .medium))
                        }
                        .foregroundStyle(Color.luxuryPrimaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.luxurySurface)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color.luxuryDivider, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }

            if netbankingDeliveryPrepared || vm.paymentSessionUrl != nil {
                statusBox(
                    title: "Waiting for customer...",
                    message: vm.paymentSessionUrl ?? "Session is ready. Once the customer completes payment, the receipt can be shown."
                )
            }

            PrimaryButton(title: "Mark as Paid", isLoading: vm.isLoading) {
                Task { await vm.processPayment(method: "netbanking") }
            }
        }
        .padding(.horizontal, Spacing.md)
    }

    private func methodButton(id: String, icon: String, title: String) -> some View {
        Button {
            vm.paymentMethod = id
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.title3)
                Text(title).font(BrandFont.body(12, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(vm.paymentMethod == id ? Color.luxuryPrimaryText : Color.luxurySurface)
            .foregroundStyle(vm.paymentMethod == id ? Color.white : Color.luxuryDeepAccent)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
            .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color.luxuryDivider, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func deliveryModeSelector(
        selection: Binding<String>,
        options: [(String, String)]
    ) -> some View {
        HStack(spacing: Spacing.sm) {
            ForEach(options, id: \.0) { option in
                Button {
                    selection.wrappedValue = option.0
                } label: {
                    Text(option.1)
                        .font(BrandFont.body(13, weight: .medium))
                        .foregroundStyle(selection.wrappedValue == option.0 ? Color.white : Color.luxuryDeepAccent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(selection.wrappedValue == option.0 ? Color.luxuryPrimary : Color.luxurySurface)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color.luxuryDivider, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func channelSelector(selection: Binding<String>) -> some View {
        HStack(spacing: Spacing.sm) {
            smallPill(title: "WhatsApp", isSelected: selection.wrappedValue == "whatsapp") {
                selection.wrappedValue = "whatsapp"
            }
            smallPill(title: "SMS", isSelected: selection.wrappedValue == "sms") {
                selection.wrappedValue = "sms"
            }
        }
    }

    private func appPills(_ apps: [String]) -> some View {
        HStack(spacing: Spacing.sm) {
            ForEach(apps, id: \.self) { app in
                Text(app)
                    .font(BrandFont.body(12, weight: .medium))
                    .foregroundStyle(Color.luxuryPrimaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.luxurySurface)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.luxuryDivider, lineWidth: 0.5))
            }
        }
    }

    private func qrPlaceholder(title: String, footer: String) -> some View {
        VStack(spacing: Spacing.md) {
            RoundedRectangle(cornerRadius: Radius.lg)
                .fill(Color.luxuryBackground)
                .frame(height: 180)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.luxuryDivider)
                        Text(title)
                            .font(BrandFont.body(14))
                            .foregroundStyle(Color.luxurySecondaryText)
                    }
                )
            Text(footer)
                .font(BrandFont.body(13, weight: .medium))
                .foregroundStyle(Color.luxuryPrimaryText)
        }
        .padding(Spacing.md)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func phoneField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .kerning(1.2)
                .foregroundStyle(Color.luxurySecondaryText)
            TextField("Enter customer phone number", text: text)
                .keyboardType(.phonePad)
                .font(BrandFont.body(14))
                .padding(Spacing.md)
                .background(Color.luxurySurface)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color.luxuryDivider, lineWidth: 0.5))
        }
    }

    private func amountCard(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .kerning(1.2)
                .foregroundStyle(Color.luxurySecondaryText)
            Text(value)
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(Color.luxuryPrimaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func cashChip(title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(BrandFont.body(13, weight: .medium))
                .foregroundStyle(Color.luxuryPrimaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.luxurySurface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.luxuryDivider, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func smallPill(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(BrandFont.body(13, weight: .medium))
                .foregroundStyle(isSelected ? Color.white : Color.luxuryDeepAccent)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isSelected ? Color.luxuryPrimary : Color.luxurySurface)
                .clipShape(Capsule())
                .overlay(Capsule().stroke(Color.luxuryDivider, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private func statusBox(title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(BrandFont.body(14, weight: .semibold))
                .foregroundStyle(Color.luxuryPrimaryText)
            Text(message)
                .font(BrandFont.body(13))
                .foregroundStyle(Color.luxurySecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Spacing.md)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 2)
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .semibold))
            .kerning(1.2)
            .foregroundStyle(Color.luxurySecondaryText)
    }

    private func formatAmount(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = value.rounded(.towardZero) == value ? 0 : 2
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}

// MARK: - ReceiptSheet
struct ReceiptSheet: View {
    @ObservedObject var vm: AssociateSalesViewModel
    @EnvironmentObject var orderStore: SharedOrderStore
    @Environment(\.dismiss) var dismiss
    let onComplete: (() -> Void)?
    @State private var rating: Double = 5
    @State private var feedback = ""
    @State private var ratingSubmitted = false
    @State private var showShareSheet = false
    @State private var shareItems: [Any] = []

    var placed: PlacedOrder? { vm.lastPlacedOrder }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.luxuryBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: Spacing.xl) {
                        // ── Success banner
                        VStack(spacing: Spacing.md) {
                            ZStack {
                                Circle().fill(Color.luxurySurface).frame(width: 80, height: 80)
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 48)).foregroundStyle(Color.luxuryPrimary)
                            }
                            Text("Order Placed Successfully!")
                                .font(.system(size: 22, weight: .semibold, design: .serif))
                                .foregroundStyle(Color.luxuryPrimaryText).multilineTextAlignment(.center)
                            if let p = placed {
                                Text("Order #\(p.orderNumber)").font(BrandFont.body(12)).foregroundStyle(Color.luxurySecondaryText).kerning(1)
                            }
                            let statusColor = vm.paymentCompleted ? Color.luxuryPrimary : Color(hex: "#C8913A")
                            HStack(spacing: 6) {
                                Circle().fill(statusColor).frame(width: 6, height: 6)
                                Text(vm.paymentCompleted ? "Status: Completed" : "Status: Pending")
                                    .font(BrandFont.body(12, weight: .medium)).foregroundStyle(statusColor)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 5)
                            .background(statusColor.opacity(0.1)).clipShape(Capsule())
                        }
                        .padding(.top, Spacing.lg)

                        // ── Receipt card
                        if let p = placed {
                            VStack(spacing: 0) {
                                VStack(spacing: 4) {
                                    Text("RECEIPT").font(.system(size: 11, weight: .semibold)).kerning(2).foregroundStyle(Color.luxurySecondaryText)
                                    Text(p.createdAt.formatted(date: .long, time: .shortened)).font(BrandFont.body(11)).foregroundStyle(Color.luxurySecondaryText)
                                }
                                .frame(maxWidth: .infinity).padding(Spacing.md)
                                BrandDivider()
                                receiptRow(label: "Customer", value: p.customer.name)
                                BrandDivider().padding(.leading, Spacing.md)
                                if let ph = p.customer.phone { receiptRow(label: "Phone", value: ph); BrandDivider().padding(.leading, Spacing.md) }
                                if let em = p.customer.email { receiptRow(label: "Email", value: em); BrandDivider().padding(.leading, Spacing.md) }
                                if let cat = p.customer.customerCategory { receiptRow(label: "Category", value: cat); BrandDivider().padding(.leading, Spacing.md) }
                                receiptRow(label: "Served by", value: p.associateName)
                                BrandDivider()
                                ForEach(Array(p.items.enumerated()), id: \.element.id) { index, item in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.product.name).font(BrandFont.body(13)).foregroundStyle(Color.luxuryPrimaryText)
                                            HStack(spacing: 6) {
                                                if let sz = item.selectedSize { Text("Size \(sz)").font(BrandFont.body(11)).foregroundStyle(Color.luxurySecondaryText) }
                                                Text("×\(item.quantity)").font(BrandFont.body(11)).foregroundStyle(Color.luxurySecondaryText)
                                                Text("@ ₹\(Int(item.product.price))").font(BrandFont.body(11)).foregroundStyle(Color.luxurySecondaryText)
                                            }
                                        }
                                        Spacer()
                                        Text("₹\(Int(item.lineTotal))").font(BrandFont.body(13, weight: .medium)).foregroundStyle(Color.luxuryPrimaryText)
                                    }
                                    .padding(.horizontal, Spacing.md).padding(.vertical, 10)
                                    if index < p.items.count - 1 { BrandDivider().padding(.leading, Spacing.md) }
                                }
                                BrandDivider()
                                HStack {
                                    Text("Total").font(BrandFont.body(15, weight: .semibold)).foregroundStyle(Color.luxuryPrimaryText)
                                    Spacer()
                                    Text("₹\(Int(p.totalAmount))").font(.system(size: 20, weight: .semibold, design: .serif)).foregroundStyle(Color.luxuryDeepAccent)
                                }.padding(Spacing.md)
                            }
                            .background(Color.luxurySurface).clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                            .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.luxuryDivider, lineWidth: 0.5))
                            .padding(.horizontal, Spacing.md)
                        }

                        // ── Download / Share receipt
                        Button {
                            if let p = placed {
                                // Build a rich text receipt and share it
                                let text = buildReceiptText(placed: p)
                                shareItems = [text]
                                showShareSheet = true
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up").font(.system(size: 14))
                                Text("Download / Share Receipt").font(BrandFont.body(14, weight: .medium))
                            }
                            .foregroundStyle(Color.luxuryPrimaryText).frame(maxWidth: .infinity).padding(.vertical, 14)
                            .background(Color.luxurySurface).clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                            .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.luxuryDivider, lineWidth: 0.5))
                        }
                        .buttonStyle(.plain).padding(.horizontal, Spacing.md)

                        // ── Rating section
                        if !ratingSubmitted {
                            VStack(alignment: .leading, spacing: Spacing.md) {
                                Text("RATE THIS SERVICE").font(.system(size: 10, weight: .semibold)).kerning(1.2).foregroundStyle(Color.luxurySecondaryText)
                                HStack(spacing: 10) {
                                    ForEach(1...5, id: \.self) { star in
                                        Button { rating = Double(star) } label: {
                                            Image(systemName: Double(star) <= rating ? "star.fill" : "star")
                                                .font(.system(size: 28))
                                                .foregroundStyle(Double(star) <= rating ? Color(hex: "#C8913A") : Color.luxuryDivider)
                                        }.buttonStyle(.plain)
                                    }
                                }
                                TextField("Optional feedback...", text: $feedback, axis: .vertical).lineLimit(3).font(BrandFont.body(14))
                                    .padding(Spacing.md).background(Color.luxuryBackground)
                                    .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                                    .overlay(RoundedRectangle(cornerRadius: Radius.md).stroke(Color.luxuryDivider, lineWidth: 0.5))
                                Button("Submit Rating") {
                                    Task {
                                        await vm.submitRating(rating: rating, feedback: feedback)
                                        ratingSubmitted = true
                                    }
                                }
                                .font(BrandFont.body(14, weight: .medium)).foregroundStyle(Color(hex: "#C8913A"))
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color(hex: "#C8913A").opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: Radius.md))
                            }
                            .padding(Spacing.md).background(Color.luxurySurface).clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                            .overlay(RoundedRectangle(cornerRadius: Radius.lg).stroke(Color.luxuryDivider, lineWidth: 0.5))
                            .padding(.horizontal, Spacing.md)
                        } else {
                            HStack {
                                Image(systemName: "star.fill").foregroundStyle(Color(hex: "#C8913A"))
                                Text("Rating submitted — your dashboard will update shortly.")
                                    .font(BrandFont.body(13)).foregroundStyle(Color.luxurySecondaryText)
                            }
                            .padding(.horizontal, Spacing.md)
                        }

                        // ── Start New Sale — NO extra alert, just clears and dismisses
                        PrimaryButton(title: "Start New Sale", isLoading: false) {
                            vm.clearCart()
                            if let onComplete = onComplete {
                                onComplete()
                            } else {
                                dismiss()
                            }
                        }
                        .padding(.horizontal, Spacing.md).padding(.bottom, Spacing.xl)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("ORDER CONFIRMED").font(.system(size: 13, weight: .semibold)).kerning(2).foregroundStyle(Color.luxuryPrimaryText)
                }
            }
            .interactiveDismissDisabled()
            // ── Share sheet presented as a proper sheet
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: shareItems)
            }
        }
    }

    @ViewBuilder
    private func receiptRow(label: String, value: String) -> some View {
        HStack {
            Text(label).font(BrandFont.body(13)).foregroundStyle(Color.luxurySecondaryText)
            Spacer()
            Text(value).font(BrandFont.body(13, weight: .medium)).foregroundStyle(Color.luxuryPrimaryText).multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, Spacing.md).padding(.vertical, 10)
    }

    private func buildReceiptText(placed p: PlacedOrder) -> String {
        var lines = [
            "══════════════════════════",
            "         RECEIPT          ",
            "══════════════════════════",
            "Order #: \(p.orderNumber)",
            "Date:    \(p.createdAt.formatted(date: .long, time: .shortened))",
            "Status:  Pending",
            "──────────────────────────",
            "CUSTOMER",
            "Name:    \(p.customer.name)"
        ]
        if let phone = p.customer.phone  { lines.append("Phone:   \(phone)") }
        if let email = p.customer.email  { lines.append("Email:   \(email)") }
        if let addr  = p.customer.address { lines.append("Address: \(addr)") }
        if let cat   = p.customer.customerCategory { lines.append("Category: \(cat)") }
        lines += [
            "──────────────────────────",
            "SERVED BY: \(p.associateName)",
            "──────────────────────────",
            "ITEMS"
        ]
        for item in p.items {
            var line = "• \(item.product.name)"
            if let sz = item.selectedSize { line += " (\(sz))" }
            line += " ×\(item.quantity)  @ ₹\(Int(item.product.price))  = ₹\(Int(item.lineTotal))"
            lines.append(line)
        }
        lines += [
            "──────────────────────────",
            "TOTAL:   ₹\(Int(p.totalAmount))",
            "══════════════════════════",
            "Thank you for your purchase!"
        ]
        return lines.joined(separator: "\n")
    }
}

// MARK: - ShareSheet
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - ProductRequestSheet
struct ProductRequestSheet: View {
    @ObservedObject var vm: AssociateSalesViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedProduct: Product?
    @State private var quantity = 1

    var body: some View {
        NavigationStack {
            ZStack {
                Color.luxuryBackground.ignoresSafeArea()
                Form {
                    Section("Select Product") {
                        Picker("Product", selection: $selectedProduct) {
                            Text("Choose a product").tag(Optional<Product>.none)
                            ForEach(vm.products) { p in Text(p.name).tag(Optional(p)) }
                        }
                    }
                    Section("Quantity Needed") { Stepper("\(quantity) unit\(quantity == 1 ? "" : "s")", value: $quantity, in: 1...100) }
                    Section {
                        Button("Raise Request to Manager") {
                            guard let p = selectedProduct else { return }
                            let id = UUID()
                            Task {
                                await vm.raiseProductRequest(product: p, quantity: quantity, associateId: id, storeId: nil)
                                dismiss()
                            }
                        }
                        .disabled(selectedProduct == nil)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { Text("PRODUCT REQUEST").font(.system(size: 13, weight: .semibold)).kerning(2).foregroundStyle(Color.luxuryPrimaryText) }
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() }.foregroundStyle(Color.luxurySecondaryText) }
            }
        }
    }
}
