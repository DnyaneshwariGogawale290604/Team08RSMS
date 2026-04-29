import SwiftUI
import Supabase
import PostgREST

struct CouponFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: DiscountViewModel
    var coupon: DiscountCoupon?
    
    @State private var code = ""
    @State private var description = ""
    @State private var discountType: DiscountCoupon.DiscountType = .percentage
    @State private var discountValue: String = ""
    @State private var maxDiscountCap: String = ""
    @State private var minOrderAmount: String = ""
    @State private var validFrom = Date()
    @State private var hasExpiry = false
    @State private var validUntil = Date().addingTimeInterval(86400 * 30)
    @State private var usageLimit: String = ""
    @State private var selectedStoreIds: Set<UUID> = []
    
    @State private var isSaving = false
    @State private var showValidationError = false
    @State private var validationMessage = ""
    @State private var showErrorAlert = false
    
    private var isEdit: Bool { coupon != nil }
    
    private var isFormValid: Bool {
        !code.isEmpty && 
        !discountValue.isEmpty && 
        !selectedStoreIds.isEmpty
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                CatalogTheme.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        if showValidationError {
                            errorBanner
                        }
                        
                        basicsSection
                        discountSection
                        validitySection
                        storesSection
                        
                        saveButton
                            .padding(.top, 8)
                    }
                    .padding(20)
                }
            }
            .navigationTitle(isEdit ? "Edit Coupon" : "New Coupon")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                    }
                    .foregroundColor(CatalogTheme.primaryText)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await save() }
                    } label: {
                        Image(systemName: "checkmark")
                    }
                    .font(.body.bold())
                    .disabled(!isFormValid || isSaving)
                    .foregroundColor(isFormValid ? CatalogTheme.primary : CatalogTheme.mutedText)
                }
            }
            .onAppear {
                setupInitialData()
            }
            .alert("Error", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(validationMessage)
            }
        }
    }
    
    private var errorBanner: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(validationMessage)
                .font(BrandFont.body(13, weight: .medium))
            Spacer()
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .foregroundColor(.red)
        .cornerRadius(12)
    }
    
    private var basicsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("BASICS")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(CatalogTheme.secondaryText)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                HStack {
                    TextField("COUPON CODE", text: $code)
                        .autocapitalization(.allCharacters)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                    
                    Button {
                        generateRandomCode()
                    } label: {
                        Text("Generate")
                            .font(BrandFont.body(13, weight: .bold))
                            .foregroundColor(CatalogTheme.primary)
                    }
                }
                .padding(.vertical, 16)
                
                Divider()
                
                TextField("Description (Optional)", text: $description)
                    .font(BrandFont.body(15))
                    .padding(.vertical, 16)
            }
            .padding(.horizontal, 16)
            .background(Color.white)
            .cornerRadius(16)
        }
    }
    
    private var discountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("DISCOUNT")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(CatalogTheme.secondaryText)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                Picker("Type", selection: Binding<DiscountCoupon.DiscountType>(
                    get: { discountType },
                    set: { discountType = $0 }
                )) {
                    ForEach([DiscountCoupon.DiscountType.percentage, .flat], id: \.self) { type in
                        Text(type.label).tag(type as DiscountCoupon.DiscountType)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.vertical, 12)
                
                Divider()
                
                HStack {
                    Text("Value")
                        .font(BrandFont.body(15, weight: .medium))
                    Spacer()
                    HStack(spacing: 4) {
                        if discountType == .flat { Text("₹") }
                        TextField("0", text: $discountValue)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        if discountType == .percentage { Text("%") }
                    }
                    .font(BrandFont.body(15, weight: .bold))
                    .foregroundColor(CatalogTheme.primary)
                }
                .padding(.vertical, 16)
                
                if discountType == .percentage {
                    Divider()
                    HStack {
                        Text("Max Cap (₹)")
                            .font(BrandFont.body(15, weight: .medium))
                        Spacer()
                        TextField("No Limit", text: $maxDiscountCap)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 100)
                            .font(BrandFont.body(15, weight: .bold))
                            .foregroundColor(CatalogTheme.primary)
                    }
                    .padding(.vertical, 16)
                }
                
                Divider()
                
                HStack {
                    Text("Min Order (₹)")
                        .font(BrandFont.body(15, weight: .medium))
                    Spacer()
                    TextField("0", text: $minOrderAmount)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .font(BrandFont.body(15, weight: .bold))
                        .foregroundColor(CatalogTheme.primary)
                }
                .padding(.vertical, 16)
            }
            .padding(.horizontal, 16)
            .background(Color.white)
            .cornerRadius(16)
        }
    }
    
    private var validitySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("VALIDITY")
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(CatalogTheme.secondaryText)
                .padding(.leading, 4)
            
            VStack(spacing: 0) {
                DatePicker("Start Date", selection: $validFrom)
                    .font(BrandFont.body(15, weight: .medium))
                    .padding(.vertical, 12)
                
                Divider()
                
                Toggle("Set Expiry Date", isOn: $hasExpiry)
                    .font(BrandFont.body(15, weight: .medium))
                    .padding(.vertical, 12)
                    .tint(CatalogTheme.primary)
                
                if hasExpiry {
                    Divider()
                    DatePicker("Expires On", selection: $validUntil)
                        .font(BrandFont.body(15, weight: .medium))
                        .padding(.vertical, 12)
                }
                
                Divider()
                
                HStack {
                    Text("Usage Limit")
                        .font(BrandFont.body(15, weight: .medium))
                    Spacer()
                    TextField("Unlimited", text: $usageLimit)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .font(BrandFont.body(15, weight: .bold))
                        .foregroundColor(CatalogTheme.primary)
                }
                .padding(.vertical, 16)
            }
            .padding(.horizontal, 16)
            .background(Color.white)
            .cornerRadius(16)
        }
    }
    
    private var storesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("APPLICABLE STORES")
                Spacer()
                Button("Select All") {
                    selectedStoreIds = Set(viewModel.stores.map(\.id))
                }
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(CatalogTheme.primary)
            }
            .font(.system(size: 13, weight: .bold))
            .foregroundColor(CatalogTheme.secondaryText)
            .padding(.leading, 4)
            
            VStack(spacing: 0) {
                if viewModel.isStoresLoading && viewModel.stores.isEmpty {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(CatalogTheme.primary)
                        Spacer()
                    }
                    .padding()
                } else if viewModel.stores.isEmpty {
                    Text("No stores available")
                        .font(BrandFont.body(14))
                        .foregroundColor(CatalogTheme.mutedText)
                        .padding()
                } else {
                    ForEach(viewModel.stores) { store in
                        Button {
                            if selectedStoreIds.contains(store.id) {
                                selectedStoreIds.remove(store.id)
                            } else {
                                selectedStoreIds.insert(store.id)
                            }
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(store.name)
                                        .font(BrandFont.body(15, weight: .bold))
                                        .foregroundColor(CatalogTheme.primaryText)
                                    Text(store.location)
                                        .font(BrandFont.body(12))
                                        .foregroundColor(CatalogTheme.secondaryText)
                                }
                                Spacer()
                                if selectedStoreIds.contains(store.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(CatalogTheme.primary)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(CatalogTheme.surface)
                                }
                            }
                            .padding(.vertical, 12)
                        }
                        
                        if store.id != viewModel.stores.last?.id {
                            Divider()
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .background(Color.white)
            .cornerRadius(16)
            
            if selectedStoreIds.isEmpty && showValidationError {
                Text("Please select at least one store")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.leading, 4)
            }
        }
    }
    
    private var saveButton: some View {
        Button {
            Task { await save() }
        } label: {
            HStack {
                if isSaving {
                    ProgressView().tint(.white)
                } else {
                    Text(isEdit ? "Update Coupon" : "Create Coupon")
                        .font(BrandFont.body(16, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(isFormValid ? CatalogTheme.primary : CatalogTheme.mutedText)
            .foregroundColor(.white)
            .cornerRadius(14)
        }
        .disabled(!isFormValid || isSaving)
    }
    
    private func setupInitialData() {
        // Ensure stores are loaded if they haven't been yet
        if viewModel.stores.isEmpty {
            Task {
                await viewModel.loadData()
            }
        }

        if let coupon = coupon {
            code = coupon.code
            description = coupon.description ?? ""
            discountType = coupon.discountType
            discountValue = "\(Int(coupon.discountValue))"
            maxDiscountCap = coupon.maxDiscountCap != nil ? "\(Int(coupon.maxDiscountCap!))" : ""
            minOrderAmount = "\(Int(coupon.minOrderAmount))"
            validFrom = coupon.validFrom
            if let until = coupon.validUntil {
                hasExpiry = true
                validUntil = until
            }
            usageLimit = coupon.usageLimit != nil ? "\(coupon.usageLimit!)" : ""
            
            // Load store visibilities
            Task {
                do {
                    let ids = try await DiscountService.shared.fetchCouponStores(couponId: coupon.id)
                    selectedStoreIds = Set(ids)
                } catch {
                    print("Error fetching coupon stores: \(error)")
                }
            }
        }
    }
    
    private func generateRandomCode() {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        code = String((0..<8).map { _ in chars.randomElement()! })
    }
    
    private func save() async {
        isSaving = true
        defer { isSaving = false }
        
        let brandId: UUID
        let currentUserId: UUID
        do {
            // Get brandId for uniqueness check and model creation
            currentUserId = try SupabaseManager.shared.client.auth.session.user.id
            struct UserBrandRow: Decodable { let brand_id: UUID }
            let rows: [UserBrandRow] = try await SupabaseManager.shared.client
                .from("users")
                .select("brand_id")
                .eq("user_id", value: currentUserId)
                .limit(1)
                .execute()
                .value
            
            guard let bId = rows.first?.brand_id else {
                throw NSError(domain: "CouponForm", code: 401, userInfo: [NSLocalizedDescriptionKey: "Brand context missing"])
            }
            brandId = bId
        } catch {
            showValidationError = true
            validationMessage = "Could not verify brand context: \(error.localizedDescription)"
            showErrorAlert = true
            return
        }
        
        // Uniqueness check for new coupons
        if !isEdit {
            do {
                let isUnique = try await DiscountService.shared.isCodeUnique(code, brandId: brandId)
                if !isUnique {
                    showValidationError = true
                    validationMessage = "Coupon code '\(code)' already exists."
                    showErrorAlert = true
                    return
                }
            } catch {
                print("Uniqueness check error: \(error)")
            }
        }
        
        let newCoupon = DiscountCoupon(
            id: coupon?.id ?? UUID(),
            brandId: brandId,
            createdBy: currentUserId,
            code: code.uppercased(),
            description: description.isEmpty ? nil : description,
            discountType: discountType,
            discountValue: Double(discountValue) ?? 0,
            minOrderAmount: Double(minOrderAmount) ?? 0,
            maxDiscountCap: discountType == .percentage ? (Double(maxDiscountCap)) : nil,
            validFrom: validFrom,
            validUntil: hasExpiry ? validUntil : nil,
            usageLimit: Int(usageLimit),
            usageCount: coupon?.usageCount ?? 0,
            isActive: coupon?.isActive ?? true
        )
        
        do {
            if isEdit {
                try await DiscountService.shared.updateCoupon(newCoupon, storeIds: Array(selectedStoreIds))
            } else {
                try await DiscountService.shared.createCoupon(newCoupon, storeIds: Array(selectedStoreIds))
            }
            await viewModel.loadData()
            dismiss()
        } catch {
            print("❌ Save Coupon Error: \(error)")
            showValidationError = true
            validationMessage = error.localizedDescription
            showErrorAlert = true
        }
    }
}

