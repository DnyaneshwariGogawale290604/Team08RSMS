import SwiftUI

struct NewAppointmentSheet: View {
    @ObservedObject var vm: AppointmentsViewModel
    @Environment(\.dismiss) var dismiss

    // Form state
    @State private var selectedCustomer: Customer? = nil
    @State private var appointmentDate: Date = {
        // Default to next round hour
        let now = Date()
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour], from: now)
        return Calendar.current.date(from: comps).map { Calendar.current.date(byAdding: .hour, value: 1, to: $0)! } ?? now
    }()
    @State private var durationMins: Int = 30
    @State private var notes: String = ""

    // Product selection: productId → quantity
    @State private var selectedProductQtys: [UUID: Int] = [:]

    // Customer picker
    @State private var customerSearch: String = ""
    @State private var showCustomerPicker = false

    // Product search
    @State private var productSearch: String = ""

    private let durationOptions = [15, 30, 45, 60, 90]

    private var filteredCatalog: [Product] {
        guard !productSearch.isEmpty else { return vm.catalog }
        return vm.catalog.filter { $0.name.localizedCaseInsensitiveContains(productSearch) }
    }

    private var filteredCustomers: [Customer] {
        guard !customerSearch.isEmpty else { return vm.customers }
        return vm.customers.filter {
            $0.name.localizedCaseInsensitiveContains(customerSearch) ||
            ($0.phone?.contains(customerSearch) == true)
        }
    }

    private var selectedProducts: [(productId: UUID, quantity: Int, notes: String?)] {
        selectedProductQtys.map { (productId: $0.key, quantity: $0.value, notes: nil) }
    }

    private var canSave: Bool {
        selectedCustomer != nil && appointmentDate > Date()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.luxuryBackground.ignoresSafeArea()
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        clientSection
                        dateTimeSection
                        durationSection
                        productsSection
                        notesSection
                    }
                    .padding(16)
                    .padding(.bottom, 40)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.luxuryPrimaryText)
                }
                ToolbarItem(placement: .principal) {
                    Text("NEW APPOINTMENT")
                        .font(.system(size: 13, weight: .semibold))
                        .kerning(2)
                        .foregroundStyle(Color.luxuryPrimaryText)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task {
                            guard let customer = selectedCustomer else { return }
                            await vm.createAppointment(
                                customerId: customer.id,
                                at: appointmentDate,
                                durationMins: durationMins,
                                notes: notes,
                                products: selectedProducts
                            )
                            if vm.errorMessage == nil { dismiss() }
                        }
                    } label: {
                        if vm.isCreating {
                            ProgressView().tint(Color.luxuryPrimaryText)
                        } else {
                            Text("Book")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(canSave ? Color.luxuryPrimaryText : Color.luxurySecondaryText)
                        }
                    }
                    .disabled(!canSave || vm.isCreating)
                }
            }
            .sheet(isPresented: $showCustomerPicker) {
                customerPickerSheet
            }
            .task { await vm.fetchCustomersAndCatalog() }
        }
    }

    // MARK: - Client section
    private var clientSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("CLIENT")
            if let customer = selectedCustomer {
                HStack(spacing: 12) {
                    Circle()
                        .fill(Color(hex: "#C8913A").opacity(0.15))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Text(String(customer.name.prefix(1)).uppercased())
                                .font(.system(size: 16, weight: .semibold, design: .serif))
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
                    Button("Change") { showCustomerPicker = true }
                        .font(BrandFont.body(13))
                        .foregroundStyle(Color.luxuryPrimaryText)
                }
                .padding(14)
                .background(Color.luxurySurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.luxuryDivider, lineWidth: 0.5))
            } else {
                Button { showCustomerPicker = true } label: {
                    HStack {
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.luxurySecondaryText)
                        Text("Select a client")
                            .font(BrandFont.body(14))
                            .foregroundStyle(Color.luxurySecondaryText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.luxuryDivider)
                    }
                    .padding(16)
                    .background(Color.luxurySurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.luxuryDivider, lineWidth: 0.5))
                }
            }
        }
    }

    // MARK: - Date & Time
    private var dateTimeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("DATE & TIME")
            DatePicker("", selection: $appointmentDate, in: Date()..., displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.graphical)
                .tint(Color.luxuryPrimaryText)
                .padding(12)
                .background(Color.luxurySurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.luxuryDivider, lineWidth: 0.5))
        }
    }

    // MARK: - Duration
    private var durationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("DURATION")
            HStack(spacing: 8) {
                ForEach(durationOptions, id: \.self) { mins in
                    Button {
                        durationMins = mins
                    } label: {
                        Text("\(mins)m")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(durationMins == mins ? Color.luxuryBackground : Color.luxuryPrimaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(durationMins == mins ? Color.luxuryPrimaryText : Color.luxurySurface)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.luxuryDivider, lineWidth: 0.5))
                    }
                }
            }
        }
    }

    // MARK: - Products of interest
    private var productsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("PRODUCTS OF INTEREST  \(selectedProductQtys.isEmpty ? "" : "(\(selectedProductQtys.count))")")
            // Search
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(Color.luxurySecondaryText).font(.system(size: 13))
                TextField("Search products…", text: $productSearch)
                    .font(BrandFont.body(13))
            }
            .padding(12)
            .background(Color.luxurySurface)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.luxuryDivider, lineWidth: 0.5))

            if vm.catalog.isEmpty {
                Text("Loading products…")
                    .font(BrandFont.body(12))
                    .foregroundStyle(Color.luxurySecondaryText)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filteredCatalog.prefix(20).enumerated()), id: \.element.id) { idx, product in
                        productRow(product)
                        if idx < min(filteredCatalog.count, 20) - 1 {
                            Divider().background(Color.luxuryDivider).padding(.leading, 14)
                        }
                    }
                }
                .background(Color.luxurySurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.luxuryDivider, lineWidth: 0.5))
            }
        }
    }

    private func productRow(_ product: Product) -> some View {
        let isSelected = selectedProductQtys[product.id] != nil
        return HStack(spacing: 12) {
            Button {
                if isSelected { selectedProductQtys.removeValue(forKey: product.id) }
                else { selectedProductQtys[product.id] = 1 }
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 20))
                    .foregroundStyle(isSelected ? Color.luxuryPrimaryText : Color.luxuryDivider)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(product.name)
                    .font(BrandFont.body(13, weight: .medium))
                    .foregroundStyle(Color.luxuryPrimaryText)
                Text(product.category)
                    .font(BrandFont.body(11))
                    .foregroundStyle(Color.luxurySecondaryText)
            }
            Spacer()
            if isSelected {
                HStack(spacing: 0) {
                    Button {
                        let q = (selectedProductQtys[product.id] ?? 1) - 1
                        if q <= 0 { selectedProductQtys.removeValue(forKey: product.id) }
                        else { selectedProductQtys[product.id] = q }
                    } label: {
                        Image(systemName: "minus").font(.system(size: 11, weight: .bold))
                            .frame(width: 26, height: 26)
                    }
                    Text("\(selectedProductQtys[product.id] ?? 1)")
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 24)
                    Button {
                        selectedProductQtys[product.id] = (selectedProductQtys[product.id] ?? 1) + 1
                    } label: {
                        Image(systemName: "plus").font(.system(size: 11, weight: .bold))
                            .frame(width: 26, height: 26)
                    }
                }
                .foregroundStyle(Color.luxuryPrimaryText)
                .background(Color.luxuryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("₹\(Int(product.price))")
                    .font(BrandFont.body(12))
                    .foregroundStyle(Color.luxurySecondaryText)
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }

    // MARK: - Notes
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel("NOTES (OPTIONAL)")
            TextEditor(text: $notes)
                .font(BrandFont.body(14))
                .foregroundStyle(Color.luxuryPrimaryText)
                .frame(minHeight: 80)
                .padding(12)
                .background(Color.luxurySurface)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.luxuryDivider, lineWidth: 0.5))
        }
    }

    // MARK: - Customer Picker Sheet
    private var customerPickerSheet: some View {
        NavigationStack {
            ZStack {
                Color.luxuryBackground.ignoresSafeArea()
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Color.luxurySecondaryText).font(.system(size: 13))
                        TextField("Search clients…", text: $customerSearch)
                            .font(BrandFont.body(14))
                    }
                    .padding(14)
                    .background(Color.luxurySurface)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.luxuryDivider, lineWidth: 0.5))
                    .padding([.horizontal, .top], 16)

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 8) {
                            ForEach(filteredCustomers) { customer in
                                Button {
                                    selectedCustomer = customer
                                    showCustomerPicker = false
                                } label: {
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color(hex: "#C8913A").opacity(0.15))
                                            .frame(width: 38, height: 38)
                                            .overlay(
                                                Text(String(customer.name.prefix(1)).uppercased())
                                                    .font(.system(size: 14, weight: .semibold, design: .serif))
                                                    .foregroundStyle(Color.luxuryPrimaryText)
                                            )
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(customer.name)
                                                .font(BrandFont.body(14, weight: .medium))
                                                .foregroundStyle(Color.luxuryPrimaryText)
                                            Text(customer.phone ?? customer.email ?? "")
                                                .font(BrandFont.body(11))
                                                .foregroundStyle(Color.luxurySecondaryText)
                                        }
                                        Spacer()
                                        if let cat = customer.customerCategory {
                                            Text(cat.uppercased())
                                                .font(.system(size: 9, weight: .bold)).kerning(0.8)
                                                .foregroundStyle(Color(hex: "#C8913A"))
                                                .padding(.horizontal, 7).padding(.vertical, 3)
                                                .background(Color(hex: "#C8913A").opacity(0.1))
                                                .clipShape(Capsule())
                                        }
                                    }
                                    .padding(.horizontal, 16).padding(.vertical, 12)
                                    .background(Color.luxurySurface)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.luxuryDivider, lineWidth: 0.5))
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                            }
                        }
                        .padding(.top, 12)
                        .padding(.bottom, 30)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("SELECT CLIENT")
                        .font(.system(size: 13, weight: .semibold)).kerning(2)
                        .foregroundStyle(Color.luxuryPrimaryText)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { showCustomerPicker = false }
                        .foregroundStyle(Color.luxuryPrimaryText)
                }
            }
        }
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .kerning(1.2)
            .foregroundStyle(Color.luxurySecondaryText)
    }
}
