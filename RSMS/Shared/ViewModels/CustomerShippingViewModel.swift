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
        public let paymentType: String?
        public let codAmount: Double?
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
            // 1. Fetch local shipment record from Project A
            let response: [OrderShipment] = try await SupabaseManager.shared.client
                .from("order_shipments")
                .select()
                .eq("order_id", value: orderId)
                .execute()
                .value
            
            guard var localShipment = response.first else {
                self.shipment = nil
                return
            }
            
            // 2. Try to fetch LIVE status from Project B (Simulator)
            do {
                struct simulatedShipment: Decodable {
                    let current_status: String
                }
                let live: [simulatedShipment] = try await SupabaseManager.shared.courierClient
                    .from("simulated_shipments")
                    .select("current_status")
                    .eq("order_id", value: orderId.uuidString)
                    .execute()
                    .value
                
                if let liveStatus = live.first?.current_status {
                    // Overlay live status onto local shipment data
                    localShipment = OrderShipment(
                        id: localShipment.id,
                        orderId: localShipment.orderId,
                        awbNumber: localShipment.awbNumber,
                        courierName: localShipment.courierName,
                        status: liveStatus,
                        estimatedDelivery: localShipment.estimatedDelivery,
                        createdAt: localShipment.createdAt
                    )
                }
            } catch {
                print("[fetchShipment] Live fetch failed (falling back to local): \(error)")
            }
            
            self.shipment = localShipment
        } catch {
            self.errorMessage = "Failed to fetch shipment: \(error.localizedDescription)"
        }
    }
    
    func fetchCodAmount(for orderId: UUID) async -> Double {
        print("[fetchCodAmount] Fetching for order: \(orderId)")
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
            
            let total = legs.reduce(0.0) { $0 + $1.total_amount }
            print("[fetchCodAmount] Resolved: \(total)")
            return total
        } catch {
            print("[fetchCodAmount] Error: \(error)")
            return 0.0
        }
    }
    
    public func bookShipment(orderId: UUID, brandId: UUID) async {
        isBooking = true
        bookingError = nil
        bookingSuccess = false
        print("[bookShipment] Starting booking for order: \(orderId)")
        defer { isBooking = false }
        
        do {
            // Step 1 — Fetch COD amount
            let codAmount = await fetchCodAmount(for: orderId)
            print("[bookShipment] Step 1: COD Amount resolved: \(codAmount)")
            
            // Step 2 — Fetch courier API key from shipping_configs + vault
            print("[bookShipment] Step 2: Fetching shipping config for brand: \(brandId)")
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
                print("[bookShipment] Error: No active shipping config found")
                throw ShippingError.noShippingConfig
            }
            print("[bookShipment] Found vault ID: \(config.api_key_vault_id)")
            
            let secrets: [VaultSecret] = try await SupabaseManager.shared.client
                .rpc("get_vault_secrets", params: ["secret_ids": [config.api_key_vault_id.uuidString]])
                .execute()
                .value
            
            guard let apiKey = secrets.first?.decryptedSecret else {
                throw ShippingError.vaultAccessFailed
            }
            
            // Step 3 — Call Project B courier-simulator via URLSession
            let url = URL(string: "\(SupabaseConfiguration.courierSimulatorURL)/courier-simulator")!
            print("[bookShipment] Calling: \(url)")
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.setValue("Bearer \(SupabaseConfiguration.courierSimulatorAnonKey)", forHTTPHeaderField: "Authorization")
            request.setValue(apiKey, forHTTPHeaderField: "X-Courier-Api-Key")
            
            let body: [String: Any] = [
                "brand_id": brandId.uuidString,
                "order_id": orderId.uuidString,
                "cod_amount": codAmount,
                "webhook_url": "https://ionszphvxhffqfwlohiv.supabase.co/functions/v1/courier-webhook"
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            print("[bookShipment] Payload: \(body)")
            
            let (data, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("[bookShipment] Status Code: \(httpResponse.statusCode)")
                
                if !(200...299).contains(httpResponse.statusCode) {
                    let errorBody = String(data: data, encoding: .utf8) ?? "No Body"
                    print("[bookShipment] Simulator Error Body: \(errorBody)")
                    
                    if httpResponse.statusCode == 409 {
                        print("[bookShipment] Conflict detected. Parsing AWB from error body...")
                        
                        struct ConflictResponse: Decodable {
                            let error: String
                            let awb: String?
                        }
                        
                        if let conflictInfo = try? JSONDecoder().decode(ConflictResponse.self, from: data),
                           let recoveredAWB = conflictInfo.awb {
                            print("[bookShipment] Recovery successful! Extracted AWB: \(recoveredAWB)")
                            let recoveredData = "{\"success\": true, \"awb\": \"\(recoveredAWB)\", \"courier\": \"RSMS Simulator\"}".data(using: .utf8)!
                            let bookingResponse = try JSONDecoder().decode(CourierBookingResponse.self, from: recoveredData)
                            return try await finalizeBooking(bookingResponse, orderId: orderId, brandId: brandId)
                        } else {
                            print("[bookShipment] Recovery failed: Could not parse AWB from body: \(errorBody)")
                            throw ShippingError.courierBookingFailed("Conflict (409) reported, and AWB recovery from body failed. Body: \(errorBody)")
                        }
                    }
                    
                    throw ShippingError.courierBookingFailed("Simulator returned \(httpResponse.statusCode): \(errorBody)")
                }
            }
            
            print("[bookShipment] Booking request accepted by simulator.")
            
            let bookingResponse = try JSONDecoder().decode(CourierBookingResponse.self, from: data)
            
            guard bookingResponse.success else {
                print("[bookShipment] Error: Booking response success=false. Message: \(bookingResponse.message ?? "None")")
                throw ShippingError.courierBookingFailed(bookingResponse.message ?? "Unknown error")
            }
            
            try await finalizeBooking(bookingResponse, orderId: orderId, brandId: brandId)
            
        } catch let error as ShippingError {
            print("[bookShipment] Known Error: \(error)")
            bookingError = error.localizedDescription
        } catch {
            print("[bookShipment] Fatal Error: \(error)")
            bookingError = error.localizedDescription
        }
    }
    
    private func finalizeBooking(_ bookingResponse: CourierBookingResponse, orderId: UUID, brandId: UUID) async throws {
        print("[finalizeBooking] Starting finalization for AWB: \(bookingResponse.awb)")
        
        // Create an isolated service role client to prevent any session interference
        let isolatedServiceRoleClient = SupabaseClient(
            supabaseURL: SupabaseConfiguration.projectURL,
            supabaseKey: SupabaseConfiguration.serviceRoleKey
        )
        
        // Step 4 — Create order_shipments row in Project A
        print("[bookShipment] Step 4: Creating local shipment record")
        let shipmentData: [String: String] = [
            "order_id": orderId.uuidString,
            "brand_id": brandId.uuidString,
            "awb_number": bookingResponse.awb,
            "courier_name": bookingResponse.courier,
            "status": "accepted"
        ]
        
        try await isolatedServiceRoleClient
            .from("order_shipments")
            .insert(shipmentData)
            .execute()
        
        // Step 5 — Update sales_orders shipping_status to "accepted" and status to "in_transit"
        print("[bookShipment] Step 5: Updating sales_orders status to in_transit")
        try await isolatedServiceRoleClient
            .from("sales_orders")
            .update([
                "shipping_status": "accepted",
                "status": "in_transit"
            ])
            .eq("order_id", value: orderId.uuidString)
            .execute()
        
        // Step 6 — Start Realtime listener
        subscribeToShipmentUpdates(for: orderId)
        
        self.lastAWB = bookingResponse.awb
        self.bookingSuccess = true
        print("[finalizeBooking] Complete!")
    }
    
    public func fetchReturnLog(for orderId: UUID) async -> ReturnLogEntry? {
        do {
            let logs: [ReturnLogEntry] = try await SupabaseManager.shared.client
                .from("returns_log")
                .select()
                .eq("order_id", value: orderId.uuidString)
                .eq("status", value: "pending_inspection")
                .execute()
                .value
            return logs.first
        } catch {
            print("[fetchReturnLog] Error: \(error)")
            return nil
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
