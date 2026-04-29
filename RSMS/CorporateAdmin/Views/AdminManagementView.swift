import SwiftUI

public struct AdminManagementView: View {
    @ObservedObject private var sessionViewModel: SessionViewModel
    @StateObject private var viewModel = AdminViewModel()
    @State private var showingCreateSheet = false
    @State private var selectedVendorForProducts: Vendor?
    @State private var showingError = false
    @State private var showingSuccess = false
    @State private var selectedStaff: StaffListItem?
    @State private var selectedVendor: Vendor?

    public init(sessionViewModel: SessionViewModel) {
        self.sessionViewModel = sessionViewModel
    }

    public    var body: some View {
        NavigationStack {
            ZStack {
                CatalogTheme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    rolePicker
                    
                    searchBar

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
                        List {
                            if viewModel.selectedRole == .vendor {
                                ForEach(viewModel.visibleVendors) { vendor in
                                    vendorCard(for: vendor)
                                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(Color.clear)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                Task { await viewModel.deleteVendor(vendor) }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            } else {
                                ForEach(viewModel.visibleStaff) { item in
                                    staffCard(for: item)
                                        .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                                        .listRowSeparator(.hidden)
                                        .listRowBackground(Color.clear)
                                        .swipeActions(edge: .trailing) {
                                            Button(role: .destructive) {
                                                Task { await viewModel.deleteStaffMember(item) }
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                }
                            }
                        }
                        .listStyle(.plain)
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
                            .foregroundColor(CatalogTheme.primaryText)
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
            .sheet(item: $selectedStaff) { item in
                StaffDetailSheet(viewModel: viewModel, item: item)
            }
            .sheet(item: $selectedVendor) { vendor in
                VendorDetailSheet(viewModel: viewModel, vendor: vendor)
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
        Picker("Role", selection: $viewModel.selectedRole) {
            ForEach(StaffRoleTab.allCases, id: \.self) { role in
                Text(role.rawValue).tag(role)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .onChange(of: viewModel.selectedRole) { newRole in
            Task { await viewModel.fetchStaff(for: newRole) }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(CatalogTheme.mutedText)
            TextField("Search by name, ID or assignment...", text: $viewModel.searchQuery)
                .font(.system(size: 15, design: .serif))
                .foregroundColor(CatalogTheme.primaryText)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(12)
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }

    @Namespace private var tabNamespace


    @ViewBuilder
    private func staffCard(for item: StaffListItem) -> some View {
        Button(action: { selectedStaff = item }) {
            HStack(alignment: .center, spacing: 14) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(CatalogTheme.surface)
                        .frame(width: 46, height: 46)
                    Text(String(item.user.displayName.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(CatalogTheme.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(item.user.displayName)
                            .font(.system(size: 16, weight: .bold, design: .serif))
                            .foregroundColor(CatalogTheme.primaryText)
                        
                        Text(item.employeeId)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(CatalogTheme.deepAccent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(CatalogTheme.surface)
                            .clipShape(Capsule())
                    }

                    Text("\(item.role.assignmentLabel): \(item.assignmentName)")
                        .font(.system(size: 14, design: .serif))
                        .foregroundColor(CatalogTheme.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(CatalogTheme.mutedText)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func vendorCard(for vendor: Vendor) -> some View {
        Button(action: { selectedVendor = vendor }) {
            HStack(alignment: .center, spacing: 14) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(CatalogTheme.surface)
                        .frame(width: 46, height: 46)
                    Text(String(vendor.name.prefix(1)).uppercased())
                        .font(.system(size: 18, weight: .bold, design: .serif))
                        .foregroundColor(CatalogTheme.primary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(vendor.name)
                        .font(.system(size: 16, weight: .bold, design: .serif))
                        .foregroundColor(CatalogTheme.primaryText)

                    let count = viewModel.vendorProductIdsByVendor[vendor.id]?.count ?? 0
                    Text("\(count) products linked")
                        .font(.system(size: 14, design: .serif))
                        .foregroundColor(CatalogTheme.secondaryText)
                }

                Spacer()

                Button("Manage") {
                    selectedVendorForProducts = vendor
                }
                .font(.system(size: 12, weight: .semibold, design: .serif))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(CatalogTheme.surface)
                .foregroundColor(CatalogTheme.deepAccent)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(CatalogTheme.mutedText)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(.plain)
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
                VStack(alignment: .leading, spacing: 28) {
                    // Vendor Details Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Basic Info")
                            .font(.system(size: 16, weight: .bold, design: .serif))
                            .foregroundColor(CatalogTheme.deepAccent)
                            .padding(.leading, 4)

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
                    }

                    // Linked Products Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Linked Products")
                            .font(.system(size: 16, weight: .bold, design: .serif))
                            .foregroundColor(CatalogTheme.deepAccent)
                            .padding(.leading, 4)

                        VStack(alignment: .leading, spacing: 0) {
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
                        }
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    }

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
                                    .font(.system(size: 16, weight: .semibold, design: .serif))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(canSave ? CatalogTheme.deepAccent : CatalogTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .disabled(!canSave)
                    .padding(.top, 10)
                }
                .padding(20)
            }
            .background(CatalogTheme.background.ignoresSafeArea())
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Add Vendor")
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundColor(CatalogTheme.primaryText)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .medium, design: .serif))
                            .foregroundColor(CatalogTheme.primaryText)
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
                                .font(.system(size: 15, weight: .semibold, design: .serif))
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
                    .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)

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
                    .shadow(color: Color.black.opacity(0.03), radius: 6, x: 0, y: 2)

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
                                    .font(.system(size: 16, weight: .semibold, design: .serif))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(CatalogTheme.deepAccent)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .padding(.top, 10)
                }
                .padding(20)
            }
            .background(CatalogTheme.background.ignoresSafeArea())
            .navigationTitle("Manage")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                selectedProductIds = viewModel.vendorProductIdsByVendor[vendor.id] ?? []
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.system(size: 14, weight: .medium, design: .serif))
                            .foregroundColor(CatalogTheme.primaryText)
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
                            .font(.system(size: 16, weight: .bold, design: .serif))
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
                                    .font(.system(size: 16, weight: .semibold, design: .serif))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(isFormValid && !viewModel.isLoading ? CatalogTheme.deepAccent : CatalogTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
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
                            .font(.system(size: 14, weight: .medium, design: .serif))
                            .foregroundColor(CatalogTheme.primaryText)
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
            employeeNumber: viewModel.nextEmployeeNumber,
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

// MARK: - Detail Sheets

private struct StaffDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AdminViewModel
    let item: StaffListItem

    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var editedEmail: String = ""
    @State private var editedPhone: String = ""

    init(viewModel: AdminViewModel, item: StaffListItem) {
        self.viewModel = viewModel
        self.item = item
        self._editedName = State(initialValue: item.user.displayName)
        self._editedEmail = State(initialValue: item.user.email ?? "")
        self._editedPhone = State(initialValue: item.user.phone ?? "")
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header Avatar Section
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(CatalogTheme.surface)
                                .frame(width: 100, height: 100)
                            Text(String(editedName.prefix(1)).uppercased())
                                .font(.system(size: 40, weight: .bold, design: .serif))
                                .foregroundColor(CatalogTheme.primary)
                        }

                        VStack(spacing: 6) {
                            if isEditing {
                                TextField("Name", text: $editedName)
                                    .font(.system(size: 24, weight: .bold, design: .serif))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(CatalogTheme.primaryText)
                            } else {
                                Text(item.user.displayName)
                                    .font(.system(size: 24, weight: .bold, design: .serif))
                                    .foregroundColor(CatalogTheme.primaryText)
                            }
                            
                            Text(item.role.rawValue)
                                .font(.system(size: 16, design: .serif))
                                .foregroundColor(CatalogTheme.secondaryText)
                        }
                    }
                    .padding(.top, 20)

                    // Details Card
                    VStack(spacing: 0) {
                        detailRow(icon: "number", label: "Employee ID", value: item.employeeId, isEditable: false)
                        sheetDivider.padding(.leading, 44)
                        
                        detailRow(icon: "envelope.fill", label: "Email", value: editedEmail, isEditable: isEditing, textBinding: $editedEmail)
                        sheetDivider.padding(.leading, 44)
                        
                        detailRow(icon: "phone.fill", label: "Phone", value: editedPhone, isEditable: isEditing, textBinding: $editedPhone)
                        sheetDivider.padding(.leading, 44)
                        
                        detailRow(icon: "building.2.fill", label: item.role.assignmentLabel, value: item.assignmentName, isEditable: false)
                        sheetDivider.padding(.leading, 44)
                        
                        detailRow(icon: "mappin.and.ellipse", label: "Location", value: item.assignmentDetail, isEditable: false)
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal, 20)

                    if isEditing {
                        Button(action: {
                            Task {
                                let success = await viewModel.deleteStaffMember(item)
                                if success { dismiss() }
                            }
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Delete User")
                                    .fontWeight(.bold)
                            }
                            .font(.system(size: 16, design: .serif))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.red.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(CatalogTheme.background.ignoresSafeArea())
            .navigationTitle("Staff Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isEditing ? "Cancel" : "Close") {
                        if isEditing {
                            editedName = item.user.displayName
                            editedEmail = item.user.email ?? ""
                            editedPhone = item.user.phone ?? ""
                            isEditing = false
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundColor(CatalogTheme.primaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            Task {
                                let success = await viewModel.updateStaffMember(
                                    userId: item.user.id,
                                    name: editedName,
                                    email: editedEmail,
                                    phone: editedPhone,
                                    role: item.role
                                )
                                if success { isEditing = false }
                            }
                        } else {
                            isEditing = true
                        }
                    }
                    .foregroundColor(CatalogTheme.primaryText)
                }
            }
        }
    }

    private func detailRow(icon: String, label: String, value: String, isEditable: Bool, textBinding: Binding<String>? = nil) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(CatalogTheme.primary)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundColor(CatalogTheme.secondaryText)
                
                if isEditable, let binding = textBinding {
                    TextField(label, text: binding)
                        .font(.system(size: 15, design: .serif))
                        .foregroundColor(CatalogTheme.primaryText)
                } else {
                    Text(value)
                        .font(.system(size: 15, design: .serif))
                        .foregroundColor(CatalogTheme.primaryText)
                }
            }
            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
    }
}

private struct VendorDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: AdminViewModel
    let vendor: Vendor

    @State private var isEditing = false
    @State private var editedName: String = ""
    @State private var editedContact: String = ""

    init(viewModel: AdminViewModel, vendor: Vendor) {
        self.viewModel = viewModel
        self.vendor = vendor
        self._editedName = State(initialValue: vendor.name)
        self._editedContact = State(initialValue: vendor.contactInfo ?? "")
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    // Header Avatar
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(CatalogTheme.surface)
                                .frame(width: 100, height: 100)
                            Text(String(editedName.prefix(1)).uppercased())
                                .font(.system(size: 40, weight: .bold, design: .serif))
                                .foregroundColor(CatalogTheme.primary)
                        }

                        VStack(spacing: 6) {
                            if isEditing {
                                TextField("Vendor Name", text: $editedName)
                                    .font(.system(size: 24, weight: .bold, design: .serif))
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(CatalogTheme.primaryText)
                            } else {
                                Text(vendor.name)
                                    .font(.system(size: 24, weight: .bold, design: .serif))
                                    .foregroundColor(CatalogTheme.primaryText)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .padding(.top, 20)

                    VStack(spacing: 0) {
                        vendorDetailRow(icon: "number", label: "Vendor ID", value: vendor.id.uuidString.prefix(8).uppercased(), isEditable: false)
                        sheetDivider.padding(.leading, 44)
                        
                        vendorDetailRow(icon: "phone.fill", label: "Contact Info", value: editedContact, isEditable: isEditing, textBinding: $editedContact)
                        sheetDivider.padding(.leading, 44)
                        
                        let count = viewModel.vendorProductIdsByVendor[vendor.id]?.count ?? 0
                        vendorDetailRow(icon: "shippingbox.fill", label: "Linked Products", value: "\(count) products", isEditable: false)
                    }
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .padding(.horizontal, 20)

                    if isEditing {
                        Button(action: {
                            Task {
                                let success = await viewModel.deleteVendor(vendor)
                                if success { dismiss() }
                            }
                        }) {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Delete Vendor")
                                    .fontWeight(.bold)
                            }
                            .font(.system(size: 16, design: .serif))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Color.red.opacity(0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }
                }
                .padding(.bottom, 40)
            }
            .background(CatalogTheme.background.ignoresSafeArea())
            .navigationTitle("Vendor Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(isEditing ? "Cancel" : "Close") {
                        if isEditing {
                            editedName = vendor.name
                            editedContact = vendor.contactInfo ?? ""
                            isEditing = false
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundColor(CatalogTheme.primaryText)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Edit") {
                        if isEditing {
                            Task {
                                let success = await viewModel.updateVendor(
                                    vendorId: vendor.id,
                                    name: editedName,
                                    contactInfo: editedContact
                                )
                                if success { isEditing = false }
                            }
                        } else {
                            isEditing = true
                        }
                    }
                    .foregroundColor(CatalogTheme.primaryText)
                }
            }
        }
    }

    private func vendorDetailRow(icon: String, label: String, value: String, isEditable: Bool, textBinding: Binding<String>? = nil) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(CatalogTheme.primary)
                .frame(width: 28)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .medium, design: .serif))
                    .foregroundColor(CatalogTheme.secondaryText)
                
                if isEditable, let binding = textBinding {
                    TextField(label, text: binding)
                        .font(.system(size: 15, design: .serif))
                        .foregroundColor(CatalogTheme.primaryText)
                } else {
                    Text(value)
                        .font(.system(size: 15, design: .serif))
                        .foregroundColor(CatalogTheme.primaryText)
                }
            }
            Spacer()
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 20)
    }
}


