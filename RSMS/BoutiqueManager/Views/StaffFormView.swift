import SwiftUI

public struct StaffFormView: View {
    // StaffFormView needs its own reference to the VM since sheets lose environment
    let staffVM: StaffViewModel
    @Environment(\.presentationMode) var presentationMode

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var phone: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showPassword: Bool = false
    @State private var role: User.Role = .sales
    @State private var isLoading = false
    @State private var errorMsg: String?

    // Performance fields (only for new staff)
    @State private var salesTargetText: String = ""
    @State private var initialRatingText: String = ""

    let userToEdit: User?

    public init(staffVM: StaffViewModel, userToEdit: User? = nil) {
        self.staffVM = staffVM
        self.userToEdit = userToEdit
    }

    public var body: some View {
        NavigationView {
            Form {
                // MARK: Personal Details
                Section(header: Text("Personal Details")) {
                    TextField("Full Name", text: $name)
                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    TextField("Phone (Optional)", text: $phone)
                        .keyboardType(.phonePad)
                }

                // MARK: Role (fixed as Sales Associate for boutique manager)
                Section(header: Text("Role Assignment")) {
                    HStack {
                        Text("Role")
                        Spacer()
                        Text("Sales Associate")
                            .foregroundColor(Theme.textSecondary)
                    }
                }

                // MARK: Password (only for new staff)
                if userToEdit == nil {
                    Section(header: Text("Account Credentials")) {
                        HStack {
                            if showPassword {
                                TextField("Password", text: $password)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            } else {
                                SecureField("Password", text: $password)
                            }
                            Button(action: { showPassword.toggle() }) {
                                Image(systemName: showPassword ? "eye.slash" : "eye")
                                    .foregroundColor(Theme.textSecondary)
                            }
                        }

                        HStack {
                            if showPassword {
                                TextField("Confirm Password", text: $confirmPassword)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            } else {
                                SecureField("Confirm Password", text: $confirmPassword)
                            }
                        }

                        if !password.isEmpty && password.count < 6 {
                            Text("Password must be at least 6 characters.")
                                .font(.caption)
                                .foregroundColor(Theme.error)
                        }
                        if !confirmPassword.isEmpty && password != confirmPassword {
                            Text("Passwords do not match.")
                                .font(.caption)
                                .foregroundColor(Theme.error)
                        }
                    }

                    // MARK: Performance Targets
                    Section(header: Text("Performance"), footer: Text("Set an initial sales target and rating for this staff member. You can update these anytime.")) {
                        HStack {
                            Text("Sales Target (₹)")
                            Spacer()
                            TextField("e.g. 50000", text: $salesTargetText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(Theme.textSecondary)
                        }

                        HStack {
                            Text("Initial Rating (1–5)")
                            Spacer()
                            TextField("e.g. 3.5", text: $initialRatingText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }

                // MARK: Error
                if let err = errorMsg {
                    Section {
                        Text(err)
                            .foregroundColor(Theme.error)
                            .font(.caption)
                    }
                }

                // MARK: Save Button
                Section {
                    Button(action: save) {
                        if isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(userToEdit == nil ? "Hire Staff" : "Update Details")
                                .frame(maxWidth: .infinity)
                                .foregroundColor(Theme.beige)
                        }
                    }
                    .disabled(isLoading || !canSave)
                    .listRowBackground(canSave ? Theme.textPrimary : Theme.border)
                }
            }
            .navigationTitle(userToEdit == nil ? "Add Staff" : "Edit Staff")
            .navigationBarItems(leading: Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark")
            })
            .onAppear {
                if let u = userToEdit {
                    name = u.name ?? ""
                    email = u.email ?? ""
                    phone = u.phone ?? ""
                    role = u.role ?? .sales
                }
            }
        }
    }

    private var canSave: Bool {
        guard !name.isEmpty, !email.isEmpty else { return false }
        if userToEdit == nil {
            // New staff requires a valid password
            guard password.count >= 6, password == confirmPassword else { return false }
        }
        return true
    }

    private func save() {
        guard canSave else {
            errorMsg = "Please fill in all required fields correctly."
            return
        }
        isLoading = true
        errorMsg = nil

        if let u = userToEdit {
            let updated = User(id: u.id, name: name, email: email, phone: phone.isEmpty ? nil : phone, brandId: u.brandId, role: role)
            staffVM.updateStaff(user: updated)
            presentationMode.wrappedValue.dismiss()
        } else {
            let salesTarget = Double(salesTargetText)
            let initialRating = Double(initialRatingText).map { min(max($0, 1.0), 5.0) }

            Task {
                do {
                    try await AuthService.shared.registerStaff(
                        email: email,
                        password: password,
                        name: name,
                        phone: phone.isEmpty ? nil : phone,
                        salesTarget: salesTarget,
                        initialRating: initialRating
                    )
                    await MainActor.run {
                        staffVM.fetchStaff()
                        presentationMode.wrappedValue.dismiss()
                    }
                } catch {
                    await MainActor.run {
                        let errStr = error.localizedDescription
                        if errStr.contains("users_user_id_fkey") || errStr.contains("already registered") {
                            errorMsg = "This email address is already registered."
                        } else if errStr.contains("stack depth limit") {
                            errorMsg = "Database Error: Please disable RLS on the 'users' table in Supabase."
                        } else {
                            errorMsg = "Failed to add staff: \(errStr)"
                        }
                        isLoading = false
                    }
                }
            }
        }
    }
}




