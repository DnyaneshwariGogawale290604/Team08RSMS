// PATH: RSMS/CorporateAdmin/Views/CourierOnboardingView.swift

import SwiftUI

struct CourierOnboardingView: View {
    @StateObject private var viewModel = ShippingViewModel()
    @State private var showCredentialsModal = false
    @State private var credentials: [String: String] = [:]
    @State private var webhookUrl = "https://ionszphvxhffqfwlohiv.supabase.co/functions/v1/shipping-webhook"
    @State private var showError = false
    
    var body: some View {
        ZStack {
            BoutiqueTheme.offWhite.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 12) {
                        Image(systemName: "truck.box.fill").font(.system(size: 60)).foregroundStyle(BoutiqueTheme.primary)
                        Text("Courier Simulator").font(BrandFont.body(22, weight: .bold))
                        CourierStatusBadge(isActive: viewModel.isConfigured)
                    }.padding(.vertical, 30)
                    
                    VStack(alignment: .leading, spacing: 20) {
                        Text("CONNECTIVITY").font(.system(size: 12, weight: .bold)).kerning(1).foregroundStyle(Color.luxurySecondaryText)
                        if !viewModel.isConfigured {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Webhook Callback URL").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.luxuryPrimaryText)
                                TextField("URL", text: $webhookUrl).font(.system(size: 14)).padding().background(Color.luxurySurface).cornerRadius(12)
                            }
                            Button { onboardBrand() } label: {
                                HStack { if viewModel.isLoading { ProgressView().tint(.white) } else { Image(systemName: "bolt.fill"); Text("Connect RSMS Simulator") } }
                                .font(BrandFont.body(16, weight: .bold)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 16).background(BoutiqueTheme.primary).cornerRadius(16)
                            }.buttonStyle(LuxuryPressStyle()).disabled(viewModel.isLoading)
                        } else {
                            VStack(spacing: 16) {
                                OnboardingInfoRow(label: "Provider", value: "RSMS Mock Courier")
                                BrandDivider()
                                OnboardingInfoRow(label: "Status", value: "Active")
                                BrandDivider()
                                OnboardingInfoRow(label: "Onboarded", value: viewModel.config?.onboardedAt?.formatted(date: .abbreviated, time: .omitted) ?? "Today")
                                Button(role: .destructive) { /* Disconnect */ } label: { Text("Disconnect Simulator").font(.subheadline.bold()).foregroundStyle(.red).padding(.top, 10) }
                            }
                        }
                    }.padding(20).background(Color.white).cornerRadius(20).shadow(color: Color.black.opacity(0.03), radius: 10, y: 5)
                }.padding(20)
            }
        }
        .navigationTitle("Shipping Config")
        .task { if let brandId = try? await DataService.shared.resolveCurrentUserBrandIdOrThrow() { await viewModel.fetchConfig(for: brandId) } }
        .sheet(isPresented: $showCredentialsModal) { CredentialsModal(credentials: credentials) { finalizeOnboarding() } }
        .alert("Configuration Error", isPresented: $showError) { Button("OK", role: .cancel) { } } message: { Text(viewModel.errorMessage ?? "An unknown error occurred.") }
    }
    
    private func onboardBrand() {
        Task {
            do {
                let brandId = try await DataService.shared.resolveCurrentUserBrandIdOrThrow()
                if let creds = await viewModel.registerCourier(brandId: brandId, webhookUrl: webhookUrl) { self.credentials = creds; self.showCredentialsModal = true } else { self.showError = true }
            } catch { viewModel.errorMessage = "Could not resolve brand: \(error.localizedDescription)"; self.showError = true }
        }
    }
    
    private func finalizeOnboarding() {
        Task {
            guard let brandId = try? await DataService.shared.resolveCurrentUserBrandIdOrThrow(),
                  let apiKey = credentials["api_key"],
                  let secret = credentials["webhook_secret"],
                  let url = credentials["webhook_url"] else { return }
            await viewModel.onboardCourier(brandId: brandId, apiKey: apiKey, webhookSecret: secret, webhookUrl: url)
        }
    }
}

private struct CourierStatusBadge: View {
    let isActive: Bool
    var body: some View {
        HStack(spacing: 6) { Circle().fill(isActive ? Color.green : Color.red).frame(width: 8, height: 8); Text(isActive ? "CONNECTED ✓" : "NOT CONNECTED") }
        .font(.system(size: 12, weight: .bold)).padding(.horizontal, 12).padding(.vertical, 6).background(isActive ? Color.green.opacity(0.1) : Color.red.opacity(0.1)).foregroundStyle(isActive ? Color.green : Color.red).clipShape(Capsule())
    }
}

struct OnboardingInfoRow: View {
    let label: String; let value: String
    var body: some View { HStack { Text(label).font(.system(size: 13)).foregroundStyle(Color.luxurySecondaryText); Spacer(); Text(value).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.luxuryPrimaryText) } }
}

struct CredentialsModal: View {
    let credentials: [String: String]; var onDismiss: () -> Void; @Environment(\.dismiss) var dismiss
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) { Image(systemName: "key.fill").font(.largeTitle).foregroundStyle(BoutiqueTheme.primary); Text("Secure Credentials").font(BrandFont.body(20, weight: .bold)); Text("Save these now. For security, we only show them once.").font(.caption).foregroundStyle(Color.luxurySecondaryText).multilineTextAlignment(.center) }.padding(.top, 20)
                VStack(spacing: 16) { CredentialField(label: "API KEY", value: credentials["api_key"] ?? ""); CredentialField(label: "WEBHOOK SECRET", value: credentials["webhook_secret"] ?? "") }
                Spacer()
                Button { onDismiss(); dismiss() } label: { Text("I have saved these safely").font(BrandFont.body(16, weight: .bold)).foregroundStyle(.white).frame(maxWidth: .infinity).padding(.vertical, 16).background(BoutiqueTheme.primary).cornerRadius(16) }.padding(.bottom, 20)
            }.padding(24).navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct CredentialField: View {
    let label: String; let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.system(size: 10, weight: .bold)).foregroundStyle(Color.luxurySecondaryText)
            HStack {
                Text(value).font(.system(size: 13, weight: .medium, design: .monospaced)).foregroundStyle(Color.luxuryPrimaryText)
                Spacer()
                Button { UIPasteboard.general.string = value } label: { Image(systemName: "doc.on.doc").font(.system(size: 14)) }
            }.padding().background(Color.luxurySurface).cornerRadius(12)
        }
    }
}
