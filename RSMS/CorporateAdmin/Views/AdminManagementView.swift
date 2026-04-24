import SwiftUI

public struct AdminManagementView: View {
    @ObservedObject private var sessionViewModel: SessionViewModel
    @StateObject private var viewModel = AdminViewModel()
    @State private var showingCreateSheet = false
    @State private var selectedVendorForProducts: Vendor?
    @State private var showingError = false
    @State private var showingSuccess = false

    public init(sessionViewModel: SessionViewModel) {
        self.sessionViewModel = sessionViewModel
    }

    public    var body: some View {
        NavigationStack {
            ZStack {
                CatalogTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    rolePicker

                    if viewModel.isLoading && isCurrentListEmpty {
                        LoadingView(message: loadingMessage)
                    } else if isCurrentListEmpty {
                        EmptyStateView(
                            icon: viewModel.selectedRole == .vendor ? "shippingbox" : "person.2.slash",
                            title: viewModel.selectedRole == .vendor ? "No Vendors Found" : "No Users Found",
                            message: viewModel.selectedRole == .vendor
                                ? "There are no vendors added for this brand yet."
                                : "There are no users assigned to this role yet."
                        )
                    } else {
                        ScrollView(showsIndicators: false) {
                            LazyVStack(spacing: 16) {
                                if viewModel.selectedRole == .vendor {
                                    ForEach(viewModel.vendors) { vendor in
                                        vendorCard(for: vendor)
                                    }
                                } else {
                                    ForEach(viewModel.visibleStaff) { user in
                                        staffCard(for: user)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 100)
                        }
                        .refreshable { await viewModel.fetchStaff(for: viewModel.selectedRole) }
                    }
                }


            }
            .navigationTitle("Staff")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: AppTheme.toolbarButtonSize, height: AppTheme.toolbarButtonSize)
                            .background(Circle().fill(CatalogTheme.deepAccent))
                            .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                    }
                }
            }
            .task {
                await viewModel.loadInitialData()
            }
            .sheet(isPresented: $showingCreateSheet) {
                if viewModel.selectedRole == .vendor {
                    VendorCreationSheet(viewModel: viewModel)
                } else {
                    StaffCreationSheet(viewModel: viewModel, role: viewModel.selectedRole)
                }
            }
            .sheet(item: $selectedVendorForProducts) { vendor in
                VendorProductsSheet(viewModel: viewModel, vendor: vendor)
            }
            .onChange(of: viewModel.errorMessage) { newValue in
                showingError = newValue != nil
            }
            .onChange(of: viewModel.successMessage) { newValue in
                showingSuccess = newValue != nil
            }
            .alert("Something went wrong", isPresented: $showingError, actions: {
                Button("OK", role: .cancel) { viewModel.errorMessage = nil }
            }, message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            })
            .alert("Success", isPresented: $showingSuccess, actions: {
                Button("OK", role: .cancel) { viewModel.successMessage = nil }
            }, message: {
                Text(viewModel.successMessage ?? "")
            })
        }
    }

    private var isCurrentListEmpty: Bool {
        viewModel.selectedRole == .vendor ? viewModel.vendors.isEmpty : viewModel.visibleStaff.isEmpty
    }

    private var loadingMessage: String {
        viewModel.selectedRole == .vendor ? "Loading vendors..." : "Loading staff..."
    }

    private var rolePicker: some View {
        let roles = StaffRoleTab.allCases
        return HStack(spacing: 4) {
            ForEach(roles, id: \.self) { role in
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.selectedRole = role
                    }
                    Task { await viewModel.fetchStaff(for: role) }
                }) {
                    Text(role.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(viewModel.selectedRole == role ? .white : CatalogTheme.deepAccent)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            ZStack {
                                if viewModel.selectedRole == role {
                                    Capsule()
                                        .fill(CatalogTheme.primary)
                                        .matchedGeometryEffect(id: "activeTab", in: tabNamespace)
                                }
                            }
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(CatalogTheme.surface)
        .clipShape(Capsule())
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
    }

    @Namespace private var tabNamespace


    @ViewBuilder
    private func staffCard(for item: StaffListItem) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(CatalogTheme.surface)
                    .frame(width: 46, height: 46)
                Text(String(item.user.displayName.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(CatalogTheme.primary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.user.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(CatalogTheme.primaryText)

                Text("ID: \(item.user.id.uuidString.prefix(8).uppercased())")
                    .font(.caption)
                    .foregroundColor(CatalogTheme.mutedText)
                    .lineLimit(1)

                if let phone = item.user.phone, !phone.isEmpty {
                    Label(phone, systemImage: "phone")
                        .font(.subheadline)
                        .foregroundColor(CatalogTheme.secondaryText)
                        .labelStyle(TintedLabelStyle(tint: CatalogTheme.primary))
                }

                if let email = item.user.email, !email.isEmpty {
                    Label(email, systemImage: "envelope")
                        .font(.subheadline)
                        .foregroundColor(CatalogTheme.secondaryText)
                        .labelStyle(TintedLabelStyle(tint: CatalogTheme.primary))
                }

                Label("\(item.role.assignmentLabel): \(item.assignmentName)", systemImage: "building.2")
                    .font(.subheadline)
                    .foregroundColor(CatalogTheme.secondaryText)
                    .labelStyle(TintedLabelStyle(tint: CatalogTheme.primary))

                Text(item.assignmentDetail)
                    .font(.caption)
                    .foregroundColor(CatalogTheme.mutedText)
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CatalogTheme.divider, lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }

    @ViewBuilder
    private func vendorCard(for vendor: Vendor) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(CatalogTheme.surface)
                    .frame(width: 46, height: 46)
                Text(String(vendor.name.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(CatalogTheme.primary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(vendor.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(CatalogTheme.primaryText)

                Text("ID: \(vendor.id.uuidString.prefix(8).uppercased())")
                    .font(.caption)
                    .foregroundColor(CatalogTheme.mutedText)
                    .lineLimit(1)

                if let contact = vendor.contactInfo, !contact.isEmpty {
                    Label(contact, systemImage: "phone.badge.plus")
                        .font(.subheadline)
                        .foregroundColor(CatalogTheme.secondaryText)
                        .labelStyle(TintedLabelStyle(tint: CatalogTheme.primary))
                }

                let count = viewModel.vendorProductIdsByVendor[vendor.id]?.count ?? 0
                Label("\(count) products linked", systemImage: "shippingbox")
                    .font(.subheadline)
                    .foregroundColor(CatalogTheme.secondaryText)
                    .labelStyle(TintedLabelStyle(tint: CatalogTheme.primary))
            }

            Spacer()

            Button("Manage Products") {
                selectedVendorForProducts = vendor
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(CatalogTheme.surface)
            .foregroundColor(CatalogTheme.deepAccent)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(CatalogTheme.divider, lineWidth: 0.8)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
    }


}

private struct VendorCreationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AdminViewModel

    @State private var name: String = ""
    @State private var contactInfo: String = ""
    @State private var selectedProductIds: Set<UUID> = []

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !viewModel.isLoading
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    // Vendor Details card
                    VStack(spacing: 0) {
                        sheetFieldRow(label: "Vendor Name") {
                            TextField("Enter vendor name", text: $name)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(CatalogTheme.primaryText)
                        }
                        sheetDivider
                        sheetFieldRow(label: "Contact Info") {
                            TextField("Phone / email", text: $contactInfo)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(CatalogTheme.primaryText)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 4)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(CatalogTheme.divider, lineWidth: 0.8))

                    // Assign Products card
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Assign Products")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(CatalogTheme.secondaryText)
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .padding(.bottom, 10)

                        ForEach(Array(viewModel.products.enumerated()), id: \.element.id) { index, product in
                            VStack(spacing: 0) {
                                if index > 0 { sheetDivider.padding(.horizontal, 16) }
                                MultipleSelectionRow(
                                    title: product.name,
                                    subtitle: product.sku ?? product.category,
                                    isSelected: selectedProductIds.contains(product.id)
                                ) { toggleProduct(product.id) }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(CatalogTheme.divider, lineWidth: 0.8))

                    // Save button
                    Button(action: {
                        Task {
                            let ok = await viewModel.createVendor(name: name, contactInfo: contactInfo, productIds: selectedProductIds)
                            if ok { dismiss() }
                        }
                    }) {
                        Group {
                            if viewModel.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Create Vendor")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 50, style: .continuous)
                            .fill(canSave ? CatalogTheme.deepAccent : CatalogTheme.surface)
                    )
                    .foregroundColor(canSave ? .white : CatalogTheme.mutedText)
                    .disabled(!canSave)
                }
                .padding(20)
            }
            .background(CatalogTheme.background.ignoresSafeArea())
            .navigationTitle("Create Vendor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(CatalogTheme.deepAccent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(CatalogTheme.surface)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private func toggleProduct(_ id: UUID) {
        if selectedProductIds.contains(id) {
            selectedProductIds.remove(id)
        } else {
            selectedProductIds.insert(id)
        }
    }
}

private struct VendorProductsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AdminViewModel
    let vendor: Vendor

    @State private var selectedProductIds: Set<UUID> = []

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    // Vendor info card
                    VStack(spacing: 0) {
                        HStack {
                            Text("Vendor")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(CatalogTheme.secondaryText)
                            Spacer()
                            Text(vendor.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(CatalogTheme.primaryText)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        if let contact = vendor.contactInfo, !contact.isEmpty {
                            sheetDivider.padding(.horizontal, 16)
                            HStack {
                                Text("Contact")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(CatalogTheme.secondaryText)
                                Spacer()
                                Text(contact)
                                    .font(.system(size: 14))
                                    .foregroundColor(CatalogTheme.mutedText)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(CatalogTheme.divider, lineWidth: 0.8))

                    // Products list card
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Linked Products")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(CatalogTheme.secondaryText)
                            .padding(.horizontal, 16)
                            .padding(.top, 14)
                            .padding(.bottom, 10)

                        ForEach(Array(viewModel.products.enumerated()), id: \.element.id) { index, product in
                            VStack(spacing: 0) {
                                if index > 0 { sheetDivider.padding(.horizontal, 16) }
                                MultipleSelectionRow(
                                    title: product.name,
                                    subtitle: product.sku ?? product.category,
                                    isSelected: selectedProductIds.contains(product.id)
                                ) { toggleProduct(product.id) }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 4)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(CatalogTheme.divider, lineWidth: 0.8))

                    // Save button
                    Button(action: {
                        Task {
                            let ok = await viewModel.saveVendorProducts(vendorId: vendor.id, selectedProductIds: selectedProductIds)
                            if ok { dismiss() }
                        }
                    }) {
                        Group {
                            if viewModel.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("Save Products")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 50, style: .continuous)
                            .fill(viewModel.isLoading ? CatalogTheme.surface : CatalogTheme.deepAccent)
                    )
                    .disabled(viewModel.isLoading)
                }
                .padding(20)
            }
            .background(CatalogTheme.background.ignoresSafeArea())
            .navigationTitle("Manage Products")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                selectedProductIds = viewModel.vendorProductIdsByVendor[vendor.id] ?? []
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(CatalogTheme.deepAccent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(CatalogTheme.surface)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private func toggleProduct(_ id: UUID) {
        if selectedProductIds.contains(id) {
            selectedProductIds.remove(id)
        } else {
            selectedProductIds.insert(id)
        }
    }
}

private struct MultipleSelectionRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundColor(isSelected ? CatalogTheme.primary : Color(hex: "#CBBABA"))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(CatalogTheme.primaryText)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(CatalogTheme.mutedText)
                }

                Spacer()
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}

private struct StaffCreationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AdminViewModel
    let role: StaffRoleTab

    @State private var name: String = ""
    @State private var phone: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var selectedStoreId: UUID?
    @State private var selectedWarehouseId: UUID?
    @State private var localError: String?

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Staff Information")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(CatalogTheme.deepAccent)
                            .padding(.leading, 4)
                        
                        formCard
                    }

                    Button(action: save) {
                        Group {
                            if viewModel.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text(role == .boutiqueManager ? "Create Boutique Manager" : "Create Inventory Manager")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(isFormValid && !viewModel.isLoading ? CatalogTheme.deepAccent : CatalogTheme.surface)
                    )
                    .foregroundColor(isFormValid && !viewModel.isLoading ? .white : CatalogTheme.mutedText)
                    .disabled(!isFormValid || viewModel.isLoading)
                }
                .padding(20)
            }
            .background(CatalogTheme.background.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(role.rawValue)
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundColor(CatalogTheme.primaryText)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(CatalogTheme.deepAccent)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(CatalogTheme.surface)
                            .clipShape(Capsule())
                    }
                }
            }
            .alert("Invalid Details", isPresented: Binding(get: {
                localError != nil
            }, set: { newValue in
                if !newValue { localError = nil }
            })) {
                Button("OK", role: .cancel) { localError = nil }
            } message: {
                Text(localError ?? "")
            }
        }
    }

    private var formCard: some View {
        VStack(spacing: 0) {
            fieldRow(label: "Employee Name") {
                TextField("Enter employee name", text: $name)
                    .multilineTextAlignment(.trailing)
            }

            divider

            fieldRow(label: "Employee ID") {
                Text(viewModel.nextEmployeeNumber)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(CatalogTheme.deepAccent)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(CatalogTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            divider

            assignmentPickerRow

            divider

            fieldRow(label: "Contact Number") {
                TextField("Phone number", text: $phone)
                    .multilineTextAlignment(.trailing)
#if canImport(UIKit)
                    .keyboardType(.phonePad)
#endif
            }

            divider

            fieldRow(label: "Email") {
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
#if canImport(UIKit)
                    .keyboardType(.emailAddress)
#endif
            }

            divider

            fieldRow(label: "Password") {
                SecureField("Password", text: $password)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous)
            .stroke(CatalogTheme.divider, lineWidth: 0.8))
    }

    private var assignmentPickerRow: some View {
        fieldRow(label: role.assignmentLabel) {
            Menu {
                switch role {
                case .boutiqueManager:
                    ForEach(viewModel.availableStores) { store in
                        Button(store.displayName) {
                            selectedStoreId = store.id
                        }
                    }

                case .inventoryManager:
                    ForEach(viewModel.availableWarehouses) { warehouse in
                        Button(warehouse.displayLabel) {
                            selectedWarehouseId = warehouse.id
                        }
                    }

                case .vendor:
                    EmptyView()
                }
            } label: {
                HStack(spacing: 6) {
                    Text(selectedAssignmentLabel)
                        .foregroundColor(selectedAssignmentIsPlaceholder ? CatalogTheme.mutedText : CatalogTheme.primaryText)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(CatalogTheme.primary)
                }
            }
        }
    }

    private var selectedAssignmentLabel: String {
        switch role {
        case .boutiqueManager:
            if let id = selectedStoreId,
               let store = viewModel.stores.first(where: { $0.id == id }) {
                return store.displayName
            }
            return viewModel.stores.isEmpty ? "No stores available" : "Select store"

        case .inventoryManager:
            if let id = selectedWarehouseId,
               let warehouse = viewModel.warehouses.first(where: { $0.id == id }) {
                return warehouse.displayLabel
            }
            return viewModel.warehouses.isEmpty ? "No warehouses available" : "Select warehouse"

        case .vendor:
            return "Not applicable"
        }
    }

    private var selectedAssignmentIsPlaceholder: Bool {
        switch role {
        case .boutiqueManager:
            return selectedStoreId == nil
        case .inventoryManager:
            return selectedWarehouseId == nil
        case .vendor:
            return false
        }
    }

    private func fieldRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(CatalogTheme.secondaryText)

            Spacer()

            content()
                .font(.system(size: 14))
                .foregroundColor(CatalogTheme.primaryText)
        }
        .padding(.vertical, 14)
    }

    private var divider: some View {
        Rectangle()
            .fill(CatalogTheme.divider)
            .frame(height: 1)
    }

    private var isFormValid: Bool {
        let assignmentValid: Bool
        switch role {
        case .boutiqueManager:
            assignmentValid = selectedStoreId != nil
        case .inventoryManager:
            assignmentValid = selectedWarehouseId != nil
        case .vendor:
            assignmentValid = false
        }

        return !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !phone.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            password.count >= 6 &&
            assignmentValid
    }

    private func save() {
        let employeeUUID = UUID()

        let request = StaffCreationRequest(
            role: role,
            employeeId: employeeUUID,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            phone: phone.trimmingCharacters(in: .whitespacesAndNewlines),
            email: email.trimmingCharacters(in: .whitespacesAndNewlines),
            password: password,
            storeId: selectedStoreId,
            warehouseId: selectedWarehouseId
        )

        Task {
            let success = await viewModel.createStaffMember(request)
            if success {
                dismiss()
            }
        }
    }
}

// MARK: - Helpers (scoped to Admin Staff tab only)

private struct TintedLabelStyle: LabelStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon
                .foregroundColor(tint)
            configuration.title
        }
    }
}

/// Shared 1pt divider for themed sheet cards
private var sheetDivider: some View {
    Rectangle()
        .fill(CatalogTheme.divider)
        .frame(height: 1)
}

/// Shared field row for themed sheet cards
@ViewBuilder
private func sheetFieldRow<Content: View>(label: String, @ViewBuilder content: () -> Content) -> some View {
    HStack(spacing: 12) {
        Text(label)
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(CatalogTheme.secondaryText)
        Spacer()
        content()
            .font(.system(size: 14))
            .foregroundColor(CatalogTheme.primaryText)
    }
    .padding(.vertical, 14)
}
