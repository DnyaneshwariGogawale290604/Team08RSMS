// PATH: RSMS/CorporateAdmin/ViewModels/ShippingViewModel.swift

import Foundation
import SwiftUI
import Combine
import Supabase

@MainActor
public class ShippingViewModel: ObservableObject {
    @Published public var config: CourierConfig?
    @Published public var isLoading = false
    @Published public var isConfigured = false
    @Published public var errorMessage: String?
    
    private let client = SupabaseManager.shared.client
    
    public struct CourierConfig: Codable {
        public let id: UUID?
        public let brandId: UUID
        public let apiKeyVaultId: UUID?
        public let webhookSecretVaultId: UUID?
        public let courierName: String?
        public let webhookUrl: String?
        public let isActive: Bool?
        public let onboardedAt: Date?
        
        enum CodingKeys: String, CodingKey {
            case id
            case brandId = "brand_id"
            case apiKeyVaultId = "api_key_vault_id"
            case webhookSecretVaultId = "webhook_secret_vault_id"
            case courierName = "courier_name"
            case webhookUrl = "webhook_url"
            case isActive = "is_active"
            case onboardedAt = "onboarded_at"
        }
    }
    
    public struct CourierRegisterResponse: Codable {
        public let success: Bool
        public let alreadyRegistered: Bool
        public let courier: String?
        public let apiKey: String
        public let webhookSecret: String
        public let message: String?
        
        enum CodingKeys: String, CodingKey {
            case success
            case alreadyRegistered = "already_registered"
            case courier
            case apiKey = "api_key"
            case webhookSecret = "webhook_secret"
            case message
        }
    }
    
    public init() {}
    
    public func fetchConfig(for brandId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response: [CourierConfig] = try await client
                .from("shipping_configs")
                .select()
                .eq("brand_id", value: brandId)
                .execute()
                .value
            
            print("ShippingVM: Fetched \(response.count) configs for brand \(brandId)")
            self.config = response.first
            self.isConfigured = !response.isEmpty
        } catch {
            print("ShippingVM: Fetch failed - \(error.localizedDescription)")
            self.errorMessage = "Failed to fetch config: \(error.localizedDescription)"
        }
    }
    
    public func registerCourier(brandId: UUID, webhookUrl: String) async -> [String: String]? {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let url = URL(string: "\(SupabaseConfiguration.courierSimulatorURL)/courier-register")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(SupabaseConfiguration.courierSimulatorAnonKey)", forHTTPHeaderField: "Authorization")
            request.setValue(SupabaseConfiguration.courierSimulatorAnonKey, forHTTPHeaderField: "apikey")
            
            let payload = ["brand_id": brandId.uuidString, "webhook_url": webhookUrl]
            request.httpBody = try JSONSerialization.data(withJSONObject: payload)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                self.errorMessage = "Registration failed: Simulator returned status \(status)"
                return nil
            }
            
            do {
                let decoded = try JSONDecoder().decode(CourierRegisterResponse.self, from: data)
                return [
                    "api_key": decoded.apiKey,
                    "webhook_secret": decoded.webhookSecret,
                    "webhook_url": webhookUrl // Pass this back too
                ]
            } catch {
                self.errorMessage = "Registration failed: \(error.localizedDescription)"
                return nil
            }
        } catch {
            self.errorMessage = "Registration failed: \(error.localizedDescription)"
            return nil
        }
    }
    
    public func onboardCourier(brandId: UUID, apiKey: String, webhookSecret: String, webhookUrl: String) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            // Step 1 — Store api_key in vault via RPC
            print("ShippingVM: Storing API key in vault...")
            let apiKeyVaultId: UUID = try await client
                .rpc("vault_create_secret", params: [
                    "secret": apiKey,
                    "name": "courier_api_key_\(brandId.uuidString)",
                    "description": "Courier API key for brand \(brandId.uuidString)"
                ])
                .execute()
                .value

            // Step 2 — Store webhook_secret in vault via RPC
            print("ShippingVM: Storing Webhook secret in vault...")
            let webhookSecretVaultId: UUID = try await client
                .rpc("vault_create_secret", params: [
                    "secret": webhookSecret,
                    "name": "courier_webhook_secret_\(brandId.uuidString)",
                    "description": "Courier webhook secret for brand \(brandId.uuidString)"
                ])
                .execute()
                .value
            
            // Step 3 — Save references to shipping_configs
            let payload: [String: String] = [
                "brand_id": brandId.uuidString,
                "courier_name": "RSMS Simulator",
                "api_key_vault_id": apiKeyVaultId.uuidString,
                "webhook_secret_vault_id": webhookSecretVaultId.uuidString,
                "webhook_url": webhookUrl,
                "is_active": "true",
                "onboarded_at": ISO8601DateFormatter().string(from: Date())
            ]
            
            print("ShippingVM: Upserting config references for brand \(brandId)...")
            try await client
                .from("shipping_configs")
                .upsert(payload, onConflict: "brand_id")
                .execute()
            
            print("ShippingVM: Onboarding successful. Refreshing config...")
            await fetchConfig(for: brandId)
        } catch {
            print("ShippingVM: Onboarding failed - \(error.localizedDescription)")
            self.errorMessage = "Onboarding failed: \(error.localizedDescription)"
        }
    }
}
