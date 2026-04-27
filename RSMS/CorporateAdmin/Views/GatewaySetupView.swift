import SwiftUI

struct GatewaySetupView: View {
    @StateObject var vm = GatewayViewModel()
    @State private var visibleSecrets: Set<String> = []
    private let initialGateway: PaymentGateway?

    init(initialGateway: PaymentGateway? = nil) {
        self.initialGateway = initialGateway
    }

    var body: some View {
        ZStack {
            Color.luxuryBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                // Status Banners
                if let error = vm.errorMessage {
                    Text(error)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red.opacity(0.8))
                        .transition(.move(edge: .top))
                }

                if let success = vm.successMessage {
                    Text(success)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.8))
                        .transition(.move(edge: .top))
                }

                ScrollView {
                    VStack(spacing: 24) {
                        // Section A: Existing Configurations
                        existingConfigsSection

                        // Section B: Add New Gateway
                        addNewGatewaySection
                    }
                    .padding(20)
                }
            }

            if vm.isLoading {
                Color.black.opacity(0.15).ignoresSafeArea()
                ProgressView()
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(12)
            }
        }
        .navigationTitle("Payment Gateway")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let initialGateway {
                vm.selectedGateway = initialGateway
            }
            await vm.fetchExistingConfigs()
        }
    }

    // MARK: - Section A: Existing Configurations
    private var existingConfigsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EXISTING CONFIGURATIONS")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.luxurySecondaryText)
                .kerning(1.2)

            if vm.existingConfigs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "creditcard")
                        .font(.system(size: 40))
                        .foregroundColor(Color.luxurySecondaryText.opacity(0.3))
                    Text("No payment gateways configured yet")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(Color.luxurySecondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
            } else {
                VStack(spacing: 12) {
                    ForEach(vm.existingConfigs) { config in
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(config.gateway.displayName)
                                    .font(.system(size: 18, weight: .bold, design: .serif))
                                    .foregroundColor(Color.luxuryPrimaryText)

                                HStack(spacing: 6) {
                                    ForEach(config.enabledMethods, id: \.self) { method in
                                        Text(method.uppercased())
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(CatalogTheme.primary.opacity(0.1))
                                            .foregroundColor(CatalogTheme.primary)
                                            .cornerRadius(4)
                                    }
                                }

                                Text("Added on \(config.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.luxurySecondaryText)
                            }

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { config.isActive },
                                set: { _ in
                                    Task { await vm.toggleActive(config: config) }
                                }
                            ))
                            .labelsHidden()
                            .tint(CatalogTheme.primary)
                        }
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
                    }
                }
            }
        }
    }

    // MARK: - Section B: Add New Gateway
    private var addNewGatewaySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ADD NEW GATEWAY")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(Color.luxurySecondaryText)
                .kerning(1.2)

            VStack(alignment: .leading, spacing: 20) {
                if vm.selectedGateway == .razorpay {
                    razorpayGuideCard
                }

                // 1. Gateway Picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(PaymentGateway.allCases) { gateway in
                            Button {
                                vm.selectedGateway = gateway
                            } label: {
                                Text(gateway.displayName)
                                    .font(.system(size: 14, weight: .semibold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(vm.selectedGateway == gateway ? CatalogTheme.primary : Color.white)
                                    .foregroundColor(vm.selectedGateway == gateway ? .white : Color.luxuryPrimaryText)
                                    .cornerRadius(20)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 20)
                                            .stroke(CatalogTheme.primary.opacity(0.2), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(LuxuryPressStyle())
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }

                // 2. Instruction Card
                HStack(spacing: 12) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(CatalogTheme.primary)
                    Text("Get your credentials from: \(vm.selectedGateway.instructionURL)")
                        .font(.system(size: 13))
                        .foregroundColor(Color.luxurySecondaryText)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(CatalogTheme.primary.opacity(0.05))
                .cornerRadius(8)

                // 3. Dynamic Credential Fields
                VStack(spacing: 16) {
                    ForEach(vm.selectedGateway.fields, id: \.key) { field in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(field.label)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(Color.luxurySecondaryText)

                            HStack {
                                if field.isSecret && !visibleSecrets.contains(field.key) {
                                    SecureField("Enter \(field.label)", text: Binding(
                                        get: { vm.credentialInputs[field.key] ?? "" },
                                        set: { vm.credentialInputs[field.key] = $0 }
                                    ))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                } else {
                                    TextField("Enter \(field.label)", text: Binding(
                                        get: { vm.credentialInputs[field.key] ?? "" },
                                        set: { vm.credentialInputs[field.key] = $0 }
                                    ))
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                }

                                if field.isSecret {
                                    Button {
                                        if visibleSecrets.contains(field.key) {
                                            visibleSecrets.remove(field.key)
                                        } else {
                                            visibleSecrets.insert(field.key)
                                        }
                                    } label: {
                                        Image(systemName: visibleSecrets.contains(field.key) ? "eye.slash" : "eye")
                                            .foregroundColor(Color.luxurySecondaryText)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.luxuryBackground.opacity(0.5))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.luxuryDivider, lineWidth: 1)
                            )
                        }
                    }
                }

                // 4. Payment Methods
                VStack(alignment: .leading, spacing: 12) {
                    Text("PAYMENT METHODS")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.luxurySecondaryText)

                    VStack(spacing: 0) {
                        Toggle("UPI", isOn: $vm.enabledUPI)
                            .padding(.vertical, 12)
                        Divider()
                        Toggle("Net Banking", isOn: $vm.enabledNetBanking)
                            .padding(.vertical, 12)
                        Divider()
                        VStack(alignment: .leading, spacing: 4) {
                            Toggle("Card", isOn: $vm.enabledCard)
                            Text("Requires card machine integration")
                                .font(.system(size: 11))
                                .foregroundColor(Color.luxurySecondaryText)
                        }
                        .padding(.vertical, 12)
                    }
                    .tint(CatalogTheme.primary)
                }

                // 5. Buttons
                VStack(spacing: 12) {
                    if let result = vm.testResult {
                        Text(result)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.green)
                            .padding(.bottom, 4)
                    }

                    Button {
                        Task { await vm.testConnection() }
                    } label: {
                        HStack {
                            if vm.isTesting {
                                ProgressView().tint(CatalogTheme.primary)
                                    .padding(.trailing, 8)
                            }
                            Text(vm.isTesting ? "Testing..." : "Test Connection")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(CatalogTheme.primary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.white)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(CatalogTheme.primary, lineWidth: 1)
                        )
                    }
                    .buttonStyle(LuxuryPressStyle())
                    .disabled(vm.isTesting || !vm.allFieldsFilled)

                    Button {
                        Task { await vm.saveGatewayConfig() }
                    } label: {
                        Text("Save Configuration")
                            .font(.system(size: 16, weight: .bold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .luxuryPrimaryButtonChrome(enabled: vm.allFieldsFilled && !vm.isLoading)
                    }
                    .buttonStyle(LuxuryPressStyle())
                    .disabled(!vm.allFieldsFilled || vm.isLoading)
                }
                .padding(.top, 8)
            }
            .padding(20)
            .background(Color.white)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 4)
        }
    }

    private var razorpayGuideCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(CatalogTheme.surface)
                        .frame(width: 38, height: 38)

                    Image(systemName: "bolt.horizontal.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(CatalogTheme.primary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Razorpay Setup")
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundColor(Color.luxuryPrimaryText)

                    Text("Use your live dashboard keys for boutique billing.")
                        .font(BrandFont.body(12))
                        .foregroundColor(Color.luxurySecondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                razorpayStepRow(number: "1", text: "Open dashboard.razorpay.com and go to Settings > API Keys.")
                razorpayStepRow(number: "2", text: "Paste the Key ID and Key Secret below.")
                razorpayStepRow(number: "3", text: "Enable the payment methods your sales team should collect in store.")
            }
        }
        .padding(16)
        .background(CatalogTheme.surface.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(CatalogTheme.primary.opacity(0.12), lineWidth: 1)
        )
    }

    private func razorpayStepRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(CatalogTheme.primary)
                .clipShape(Circle())

            Text(text)
                .font(BrandFont.body(12))
                .foregroundColor(Color.luxuryPrimaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
