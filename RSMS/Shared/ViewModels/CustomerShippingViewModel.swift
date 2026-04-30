// PATH: RSMS/Shared/ViewModels/CustomerShippingViewModel.swift

import Foundation
import SwiftUI
import Combine
import Supabase
import Realtime

@MainActor
public class CustomerShippingViewModel: ObservableObject {
    @Published public var shipment: OrderShipment?
    @Published public var returnsQueue: [ReturnLogEntry] = []
    @Published public var isLoading = false
    @Published public var errorMessage: String?
    
    // Shipping Booking State
    @Published public var isBooking: Bool = false
    @Published public var bookingError: String? = nil
    @Published public var bookingSuccess: Bool = false
    @Published public var lastAWB: String? = nil
    
    private var realtimeChannel: RealtimeChannel?
    
    public enum ShippingError: LocalizedError {
        case noShippingConfig
        case vaultAccessFailed
        case courierBookingFailed(String)
        case orderUpdateFailed
        
        public var errorDescription: String? {
            switch self {
            case .noShippingConfig:
                return "No active courier configuration found. Please contact your manager."
            case .vaultAccessFailed:
                return "Could not retrieve courier credentials. Please try again."
            case .courierBookingFailed(let msg):
                return "Courier booking failed: \(msg)"
            case .orderUpdateFailed:
                return "Shipment booked but order status could not be updated."
            }
        }
    }
    
    public struct OrderShipment: Codable, Identifiable {
        public let id: UUID
        public let orderId: UUID
        public let awbNumber: String?
        public let courierName: String?
        public let status: String
        public let estimatedDelivery: Date?
        public let createdAt: Date
        enum CodingKeys: String, CodingKey {
            case id, status, orderId = "order_id", awbNumber = "awb_number", courierName = "courier_name", estimatedDelivery = "estimated_delivery", createdAt = "created_at"
        }
    }
    
    public struct ReturnLogEntry: Codable, Identifiable {
        public let id: UUID
        public let orderId: UUID
        public let productId: UUID
        public let returnReason: String
        public let condition: String
        public let status: String
        public let resolution: String?
        public let createdAt: Date
        public let inspectedAt: Date?
        public var productName: String?
        enum CodingKeys: String, CodingKey {
            case id, condition, status, resolution, orderId = "order_id", productId = "product_id", returnReason = "return_reason", createdAt = "created_at", inspectedAt = "inspected_at"
        }
    }
    
    public struct CourierBookingResponse: Codable {
        public let success: Bool
        public let awb: String
        public let courier: String
        public let paymentType: String
        public let codAmount: Double
        public let estimatedDelivery: String?
        public let message: String?
        
        enum CodingKeys: String, CodingKey {
            case success, awb, courier, message
            case paymentType = "payment_type"
            case codAmount = "cod_amount"
            case estimatedDelivery = "estimated_delivery"
        }
    }
    
    public struct VaultSecret: Codable {
        public let id: UUID
        public let decryptedSecret: String?
        
        enum CodingKeys: String, CodingKey {
            case id
            case decryptedSecret = "decrypted_secret"
        }
    }
    
    public init() {}
    
    public func fetchShipment(for orderId: UUID) async {
        isLoading = true; defer { isLoading = false }
        do {
            let response: [OrderShipment] = try await SupabaseManager.shared.client.from("order_shipments").select().eq("order_id", value: orderId).execute().value
            self.shipment = response.first
        } catch { self.errorMessage = "Failed to fetch shipment: \(error.localizedDescription)" }
    }
    
    func fetchCodAmount(for orderId: UUID) async -> Double {
        do {
            struct PaymentLeg: Decodable {
                let total_amount: Double
                let due_type: String
                let status: String
            }
            let legs: [PaymentLeg] = try await SupabaseManager.shared.client
                .from("payment_legs")
                .select("total_amount, due_type, status")
                .eq("sales_order_id", value: orderId.uuidString)
                .eq("due_type", value: "on_delivery")
                .eq("status", value: "pending")
                .execute()
                .value
            
            return legs.reduce(0.0) { $0 + $1.total_amount }
        } catch {
            print("[fetchCodAmount] Error: \(error)")
            return 0.0
        }
    }
    
    public func bookShipment(orderId: UUID, brandId: UUID) async {
        isBooking = true
        bookingError = nil
        bookingSuccess = false
        defer { isBooking = false }
        
        do {
            // Step 1 — Fetch COD amount
            let codAmount = await fetchCodAmount(for: orderId)
            
            // Step 2 — Fetch courier API key from shipping_configs + vault
            struct ShippingConfig: Decodable {
                let api_key_vault_id: UUID
            }
            let configs: [ShippingConfig] = try await SupabaseManager.shared.client
                .from("shipping_configs")
                .select("api_key_vault_id")
                .eq("brand_id", value: brandId.uuidString)
                .eq("is_active", value: true)
                .execute()
                .value
            
            guard let config = configs.first else {
                throw ShippingError.noShippingConfig
            }
            
            let secrets: [VaultSecret] = try await SupabaseManager.shared.client
                .rpc("get_vault_secrets", params: ["secret_ids": [config.api_key_vault_id.uuidString]])
                .execute()
                .value
            
            guard let apiKey = secrets.first?.decryptedSecret else {
                throw ShippingError.vaultAccessFailed
            }
            
            // Step 3 — Call Project B courier-simulator via URLSession
            let url = URL(string: "\(SupabaseConfiguration.courierSimulatorURL)/courier-simulator")!
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(SupabaseConfiguration.courierSimulatorAnonKey)", forHTTPHeaderField: "Authorization")
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "X-Courier-Api-Key")
            
            let body: [String: Any] = [
                "order_id": orderId.uuidString,
                "cod_amount": codAmount
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONDecoder().decode(CourierBookingResponse.self, from: data)
            
            guard response.success else {
                throw ShippingError.courierBookingFailed(response.message ?? "Unknown error")
            }
            
            // Step 4 — Create order_shipments row in Project A
            try await SupabaseManager.shared.client
                .from("order_shipments")
                .insert([
                    "order_id": orderId.uuidString,
                    "brand_id": brandId.uuidString,
                    "awb_number": response.awb,
                    "courier_name": response.courier,
                    "courier_provider": "RSMS Simulator",
                    "status": "accepted"
                ])
                .execute()
            
            // Step 5 — Update sales_orders shipping_status to "accepted"
            try await SupabaseManager.shared.client
                .from("sales_orders")
                .update(["shipping_status": "accepted"])
                .eq("order_id", value: orderId.uuidString)
                .execute()
            
            // Step 6 — Start Realtime listener
            subscribeToShipmentUpdates(for: orderId)
            
            self.lastAWB = response.awb
            self.bookingSuccess = true
            
        } catch let error as ShippingError {
            self.bookingError = error.errorDescription
        } catch {
            self.bookingError = error.localizedDescription
        }
    }
    
    public func subscribeToShipmentUpdates(for orderId: UUID) {
        realtimeChannel?.unsubscribe()
        let channel = SupabaseManager.shared.client.realtime.channel("shipment-\(orderId)")
        channel.on("postgres_changes", filter: ChannelFilter(event: "UPDATE", schema: "public", table: "order_shipments", filter: "order_id=eq.\(orderId)")) { _ in
            Task { @MainActor in await self.fetchShipment(for: orderId) }
        }
        self.realtimeChannel = channel; channel.subscribe()
    }
    
    public func fetchReturnsQueue(for brandId: UUID) async {
        isLoading = true; defer { isLoading = false }
        do {
            let response: [ReturnLogEntry] = try await SupabaseManager.shared.client.from("returns_log").select("*, products(name)").eq("brand_id", value: brandId).eq("status", value: "pending_inspection").order("created_at", ascending: false).execute().value
            self.returnsQueue = response
        } catch { self.errorMessage = "Failed to load returns: \(error.localizedDescription)" }
    }
    
    public func processReturn(returnLogId: UUID, inspectedBy: UUID, condition: String, resolution: String) async -> Bool {
        isLoading = true; defer { isLoading = false }
        do {
            let payload = ["return_log_id": returnLogId.uuidString, "inspected_by": inspectedBy.uuidString, "condition": condition.lowercased(), "resolution": resolution.lowercased()]
            try await SupabaseManager.shared.client.functions.invoke("restock-item", options: .init(body: payload))
            return true
        } catch { self.errorMessage = "Return processing failed: \(error.localizedDescription)"; return false }
    }
    
    public func resendShipment(returnLogId: UUID, inspectedBy: UUID) async -> Bool {
        isLoading = true; defer { isLoading = false }
        do {
            let payload = ["return_log_id": returnLogId.uuidString, "inspected_by": inspectedBy.uuidString]
            try await SupabaseManager.shared.client.functions.invoke("resend-shipment", options: .init(body: payload))
            return true
        } catch { self.errorMessage = "Resend failed: \(error.localizedDescription)"; return false }
    }
    
    deinit { realtimeChannel?.unsubscribe() }
}
