import SwiftUI
import Supabase
import PostgREST
import Combine
import Razorpay

@MainActor
class AssociateSalesViewModel: NSObject, ObservableObject {

    private let client = SupabaseManager.shared.client
    private var razorpay: RazorpayCheckout?

    // MARK: Customer
    @Published var customers: [Customer] = []
    @Published var selectedCustomer: Customer?
    @Published var customerSearch = ""

    // MARK: Cart
    @Published var cartItems: [CartItem] = []
    @Published var recommendedProducts: [Product] = []
    @Published var recommendationDiagnosticMessage: String?

    // MARK: Products
    @Published var products: [Product] = []
    @Published var productSearch = ""

    // MARK: Order
    @Published var currentOrder: SalesOrder?
    @Published var currentTransaction: Transaction?
    @Published var lastPlacedOrder: PlacedOrder?
    @Published var paymentOrderId: String? = nil
    @Published var gatewayOrderId: String? = nil
    @Published var checkoutKey: String? = nil
    @Published var paymentSessionUrl: String? = nil
    @Published var paymentSessionToken: String? = nil
    @Published var cashfreeSessionId: String? = nil
    @Published var payuHash: String? = nil
    @Published var cashTendered: Double = 0
    @Published var cashNote: String = ""
    @Published var paymentMethod: String = "upi"
    /// Set to true after payment is confirmed (cash record saved or Razorpay verified)
    @Published var paymentCompleted: Bool = false
    @Published var gatewayConfigured: Bool = false
    @Published var activeGateway: String = ""
    @Published var enabledPaymentMethods: [String] = ["cash"]
    @Published var isLoadingGatewayConfig: Bool = false
    @Published var maxPaymentLegs: Int = 2
    @Published var maxLegSplits: Int = 2

    // MARK: UI State
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // MARK: Toast (add-to-cart feedback)
    @Published var cartToastProduct: String? = nil
    @Published var showCartToast = false

    // MARK: Sheets
    @Published var showCustomerSheet = false
    @Published var showProductPicker = false
    @Published var showPayment = false
    @Published var showReceipt = false
    @Published var showProductRequest = false
    @Published var showBilling = false

    // MARK: Billing
    @Published var billingLegs: [BillingLeg] = []
    @Published var orderPaymentSummary: OrderPaymentSummary? = nil
    @Published var isLoadingPaymentSummary: Bool = false
    @Published var currentAppointmentId: UUID? = nil
    @Published var currentPaymentLegIndex: Int = 0
    @Published var currentPaymentItemIndex: Int = 0
    @Published var remainingPaymentAmount: Double = 0 // For balance payments
    @Published var gatewayReceiptUrl: String? = nil

    // MARK: Cart Helpers
    var cartTotal: Double { cartItems.reduce(0) { $0 + $1.lineTotal } }
    var cartCount: Int    { cartItems.reduce(0) { $0 + $1.quantity } }

    // MARK: - Add to Cart (with toast)
    func addToCart(product: Product, quantity: Int = 1, size: String? = nil) {
        if let idx = cartItems.firstIndex(where: { $0.product.id == product.id && $0.selectedSize == size }) {
            cartItems[idx].quantity += quantity
        } else {
            cartItems.append(CartItem(product: product, quantity: quantity, selectedSize: size))
        }
        cartToastProduct = product.name
        showCartToast = true
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            showCartToast = false
            cartToastProduct = nil
        }
    }

    func removeFromCart(item: CartItem) { cartItems.removeAll { $0.id == item.id } }

    func updateQuantity(item: CartItem, quantity: Int) {
        if let idx = cartItems.firstIndex(where: { $0.id == item.id }) {
            if quantity <= 0 { cartItems.remove(at: idx) }
            else { cartItems[idx].quantity = quantity }
        }
    }

    func clearCart() {
        cartItems.removeAll()
        selectedCustomer = nil
        currentOrder = nil
        currentTransaction = nil
        paymentCompleted = false
        paymentOrderId = nil
        gatewayOrderId = nil
        checkoutKey = nil
        billingLegs = []
        orderPaymentSummary = nil
    }

    func resetOrderContext() {
        currentOrder = nil
        billingLegs = []
        orderPaymentSummary = nil
        paymentOrderId = nil
        gatewayOrderId = nil
        checkoutKey = nil
    }

    // MARK: - Fetch Customers
    func fetchCustomers(search: String = "") async {
        do {
            let brandId = try await fetchBrandId()
            let all: [Customer] = try await client
                .from("customers")
                .select()
                .eq("brand_id", value: brandId)
                .order("name")
                .execute()
                .value
            customers = search.isEmpty ? all : all.filter {
                $0.name.localizedCaseInsensitiveContains(search) ||
                ($0.phone?.contains(search) ?? false) ||
                ($0.email?.localizedCaseInsensitiveContains(search) ?? false)
            }
        } catch is CancellationError {
            // Pull-to-refresh was cancelled by SwiftUI — silently ignore
        } catch {
            print(error)
            errorMessage = "Could not load customers."
        }
    }

    // MARK: - Create Customer
    func createCustomer(
        name: String, phone: String, email: String, gender: String?, dateOfBirth: String?,
        address: String?, nationality: String?, notes: String?, category: String
    ) async -> Bool {
        isLoading = true
        errorMessage = nil
        do {
            struct CustomerInsert: Encodable {
                let name: String
                let phone: String?
                let email: String?
                let gender: String?
                let date_of_birth: String?
                let address: String?
                let nationality: String?
                let notes: String?
                let customer_category: String
                let brand_id: String
            }
            let brandId = try await fetchBrandId()
            let payload = CustomerInsert(
                name: name,
                phone: phone.isEmpty ? nil : phone,
                email: email.isEmpty ? nil : email,
                gender: gender?.isEmpty == false ? gender : nil,
                date_of_birth: dateOfBirth?.isEmpty == false ? dateOfBirth : nil,
                address: address?.isEmpty == false ? address : nil,
                nationality: nationality?.isEmpty == false ? nationality : nil,
                notes: notes?.isEmpty == false ? notes : nil,
                customer_category: category,
                brand_id: brandId
            )

            let newCustomer: Customer = try await client
                .from("customers")
                .insert(payload)
                .select()
                .single()
                .execute()
                .value

            customers.insert(newCustomer, at: 0)
            selectedCustomer = newCustomer
            isLoading = false
            return true
        } catch {
            errorMessage = "Could not create customer."
            isLoading = false
        }
    return false
    }

    // MARK: - Fetch Products
    func fetchProducts(search: String = "") async {
        do {
            let brandId = try await fetchBrandId()
            let all: [Product] = try await client
                .from("products")
                .select()
                .eq("brand_id", value: brandId)
                .order("name")
                .execute()
                .value
            products = search.isEmpty ? all : all.filter {
                $0.name.localizedCaseInsensitiveContains(search) ||
                $0.category.localizedCaseInsensitiveContains(search)
            }
            
            // Also fetch recommendations based on cart if cart is not empty
            if !cartItems.isEmpty {
                Task {
                    await fetchRecommendations(from: all)
                }
            } else {
                recommendedProducts = []
                recommendationDiagnosticMessage = nil
            }
        } catch is CancellationError {
            // Pull-to-refresh cancellation from SwiftUI; keep current state.
        } catch {
            errorMessage = "Could not load products."
        }
    }

    private func fetchRecommendations(from catalog: [Product]) async {
        let result = await GenerativeRecommendationService.shared.getRecommendationsResult(
            cartItems: cartItems.map { $0.product },
            availableCatalog: catalog
        )
        await MainActor.run {
            self.recommendedProducts = result.products
            self.recommendationDiagnosticMessage = result.diagnosticMessage
        }
    }

    func raiseProductRequest(product: Product, quantity: Int, associateId: UUID, storeId: UUID?) async {}

    func placeOrder(
        orderStore: SharedOrderStore,
        appointmentId: UUID? = nil,
        appointmentsVM: AppointmentsViewModel? = nil
    ) async {
        guard let customer = selectedCustomer, !cartItems.isEmpty else { return }
        isLoading = true
        errorMessage = nil

        // MARK: Resolve auth
        let associateId: UUID
        let associateName: String
        do {
            let authClient = SupabaseManager.shared.client.auth
            if let session = try? await authClient.session {
                associateId = session.user.id
                associateName = session.user.userMetadata["full_name"] as? String
                    ?? session.user.email
                    ?? "Sales Associate"
            } else {
                let user = try await authClient.user()
                associateId = user.id
                associateName = user.userMetadata["full_name"] as? String
                    ?? user.email
                    ?? "Sales Associate"
            }
        } catch {
            print("[placeOrder] Auth resolution failed: \(error)")
            self.errorMessage = "Unable to verify your session. Please sign out and sign back in."
            self.isLoading = false
            return
        }

        let newId    = UUID()
        let orderNum = String(newId.uuidString.prefix(8).uppercased())
        let snapshot = cartItems
        let total    = cartTotal
        let localOrderStatus = "pending"

        // MARK: Persist to Supabase (awaited — order must exist before rating can reference it)
        do {
            // Look up the associate's store_id so the order is tied to the current boutique.
            struct SAStoreRow: Decodable { let store_id: UUID }
            let saRows: [SAStoreRow] = try await SupabaseManager.shared.client
                .from("sales_associates")
                .select("store_id")
                .eq("user_id", value: associateId.uuidString)
                .limit(1)
                .execute()
                .value
            guard let storeId = saRows.first?.store_id else {
                throw NSError(
                    domain: "AssociateSales",
                    code: 1001,
                    userInfo: [NSLocalizedDescriptionKey: "Your sales associate account is not assigned to a store."]
                )
            }

            struct SOInsert: Encodable {
                let order_id: UUID
                let customer_id: UUID
                let sales_associate_id: UUID
                let total_amount: Double
                let store_id: UUID
                let appointment_id: UUID?
            }
            struct OIInsert: Encodable {
                let order_id: UUID; let product_id: UUID
                let quantity: Int; let price_at_purchase: Double
            }
            try await SupabaseManager.shared.client
                .from("sales_orders")
                .insert(SOInsert(
                    order_id: newId,
                    customer_id: customer.id,
                    sales_associate_id: associateId,
                    total_amount: total,
                    store_id: storeId,
                    appointment_id: appointmentId
                ))
                .execute()

            let items = snapshot.map {
                OIInsert(order_id: newId, product_id: $0.product.id,
                         quantity: $0.quantity, price_at_purchase: $0.product.price)
            }
            do {
                try await SupabaseManager.shared.client
                    .from("order_items")
                    .insert(items)
                    .execute()
            } catch {
                try? await SupabaseManager.shared.client
                    .from("sales_orders")
                    .delete()
                    .eq("order_id", value: newId.uuidString)
                    .execute()
                throw error
            }

            let order = SalesOrder(
                id: newId,
                customerId: customer.id,
                salesAssociateId: associateId,
                storeId: storeId,
                totalAmount: total,
                status: nil,
                createdAt: Date(),
                ratingValue: nil,
                ratingFeedback: nil
            )
            self.currentOrder = order

            // Note: Deletion is handled by the create-billing edge function
            // when the payment is finalized. Removing it here to prevent
            // "Appointment not found" errors during billing setup.
            /*
            if let apptId = appointmentId, let avm = appointmentsVM {
                await avm.deleteAppointment(id: apptId)
            }
            */

            // Receipt row — fire-and-forget
            Task {
                struct RcptInsert: Encodable { let order_id: UUID }
                try? await SupabaseManager.shared.client
                    .from("receipts").insert(RcptInsert(order_id: newId)).execute()
            }
        } catch {
            print("[placeOrder] DB save failed: \(error)")
            self.errorMessage = "Order could not be saved: \(friendlyOrderSaveError(error))"
            self.isLoading = false
            return
        }

        // MARK: Show receipt
        let placed = PlacedOrder(
            id: newId, orderNumber: orderNum,
            customer: customer, items: snapshot,
            totalAmount: total, status: localOrderStatus,
            createdAt: Date(), associateName: associateName
        )
        lastPlacedOrder = placed
        orderStore.addOrder(placed)
        isLoading = false
        // showReceipt = true // Replaced by BillingView flow

        NotificationCenter.default.post(
            name: NSNotification.Name("RefreshSalesAssociateDashboard"), object: nil)
    }

    /// Updates an existing order's total and items in Supabase to match the current cart.
    func syncOrderWithCart(appointmentId: UUID? = nil) async {
        guard let order = currentOrder, !cartItems.isEmpty else { return }
        
        // Check if anything actually changed to avoid unnecessary DB calls
        if abs(order.totalAmount - cartTotal) < 0.01 {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            let orderId = order.id
            let newTotal = cartTotal
            
            // 1. Update the main order total
            struct SOUpdate: Encodable { let total_amount: Double }
            try await client
                .from("sales_orders")
                .update(SOUpdate(total_amount: newTotal))
                .eq("order_id", value: orderId.uuidString)
                .execute()
            
            // 2. Delete old items and insert current ones
            try await client
                .from("order_items")
                .delete()
                .eq("order_id", value: orderId.uuidString)
                .execute()
            
            struct OIInsert: Encodable {
                let order_id: UUID; let product_id: UUID
                let quantity: Int; let price_at_purchase: Double
            }
            let items = cartItems.map {
                OIInsert(order_id: orderId, product_id: $0.product.id,
                         quantity: $0.quantity, price_at_purchase: $0.product.price)
            }
            try await client
                .from("order_items")
                .insert(items)
                .execute()
            
            // 3. RESET BILLING: Delete existing legs and items by order_id
            // (Note: appointment_id is linked via the sales_orders table, not directly in payment_legs)
            
            // We must fetch leg IDs first to delete associated items (FK constraint)
            struct LegID: Decodable { let id: UUID }
            let existingLegs: [LegID] = try await client
                .from("payment_legs")
                .select("id")
                .eq("sales_order_id", value: orderId.uuidString)
                .execute()
                .value
            
            if !existingLegs.isEmpty {
                let ids = existingLegs.map { $0.id.uuidString }
                print("[syncOrderWithCart] Found \(ids.count) existing legs. Deleting items first...")
                
                try await client
                    .from("payment_leg_items")
                    .delete()
                    .in("payment_leg_id", value: ids)
                    .execute()
                
                print("[syncOrderWithCart] Items deleted. Deleting legs...")
                
                try await client
                    .from("payment_legs")
                    .delete()
                    .eq("sales_order_id", value: orderId.uuidString)
                    .execute()
                
                print("[syncOrderWithCart] Legs deleted successfully.")
                
                // Short delay to allow DB propagation before UI re-fetches
                try? await Task.sleep(nanoseconds: 500_000_000)
            } else {
                print("[syncOrderWithCart] No existing billing legs found to delete.")
            }
            
            // 4. Update local state
            await MainActor.run {
                self.currentOrder?.totalAmount = newTotal
                self.billingLegs = [] // Force re-initialization
                self.isLoading = false
            }
            
            print("[syncOrderWithCart] Successfully updated order \(orderId) to ₹\(newTotal)")
        } catch {
            print("[syncOrderWithCart] Failed: \(error)")
            errorMessage = "Failed to update order: \(error.localizedDescription)"
            isLoading = false
        }
    }

    private func friendlyOrderSaveError(_ error: Error) -> String {
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !message.isEmpty, message != "The operation couldn’t be completed." {
            return message
        }
        return String(describing: error)
    }

    func fetchBrandId() async throws -> String {
        let authId = (try await resolveUserId()).uuidString
        print("[fetchBrandId] Resolving for user: \(authId)")

        // 1. Check users table first (like Admin/Inventory)
        struct UserRow: Decodable { let brand_id: UUID? }
        let userRows: [UserRow] = (try? await SupabaseManager.shared.client
            .from("users")
            .select("brand_id")
            .eq("user_id", value: authId)
            .limit(1)
            .execute()
            .value) ?? []

        if let bId = userRows.first?.brand_id {
            print("[fetchBrandId] Resolved via users table: \(bId)")
            return bId.uuidString
        }

        // 2. Fallback: resolve via store
        print("[fetchBrandId] No brand_id in users, falling back to store resolution")
        struct SARow: Decodable { let store_id: UUID }
        let saRows: [SARow] = try await SupabaseManager.shared.client
            .from("sales_associates")
            .select("store_id")
            .eq("user_id", value: authId)
            .limit(1)
            .execute()
            .value

        guard let storeId = saRows.first?.store_id else {
            throw NSError(domain: "PaymentError", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Sales associate record not found"])
        }

        struct StoreRow: Decodable { let brand_id: UUID }
        let storeRows: [StoreRow] = try await SupabaseManager.shared.client
            .from("stores")
            .select("brand_id")
            .eq("store_id", value: storeId.uuidString)
            .limit(1)
            .execute()
            .value

        guard let brandId = storeRows.first?.brand_id else {
            throw NSError(domain: "PaymentError", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Brand not found for this store"])
        }
        print("[fetchBrandId] Resolved via store: \(brandId)")
        return brandId.uuidString
    }

    func fetchPaymentConfig() async {
        isLoadingGatewayConfig = true
        defer { isLoadingGatewayConfig = false }

        do {
            let brandId = try await fetchBrandId()
            let session = try await SupabaseManager.shared.client.auth.session

            let url = URL(string: "https://ionszphvxhffqfwlohiv.supabase.co/functions/v1/get-payment-config")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(session.accessToken)",
                         forHTTPHeaderField: "Authorization")
            req.httpBody = try JSONSerialization.data(
                withJSONObject: ["brand_id": brandId]
            )

            let (data, _) = try await URLSession.shared.data(for: req)
            if let rawString = String(data: data, encoding: .utf8) {
                print("[get-payment-config] RAW RESPONSE: \(rawString)")
            }
            guard let json = try JSONSerialization.jsonObject(with: data)
                    as? [String: Any] else { return }

            let configured = json["configured"] as? Bool ?? false
            let gateway = json["gateway"] as? String ?? ""
            let methods = json["enabled_methods"] as? [String] ?? []
            let maxLegs = json["max_payment_legs"] as? Int ?? 2
            let maxSplits = json["max_leg_splits"] as? Int ?? 2

            // If the gateway has online methods enabled, surface "online" as a unified method
            var allMethods: [String] = []
            if !methods.isEmpty && configured {
                allMethods.append("online")
            }
            allMethods.append("cash")

            await MainActor.run {
                self.gatewayConfigured = configured
                self.activeGateway = gateway
                self.enabledPaymentMethods = configured ? allMethods : ["cash"]
                self.maxPaymentLegs = maxLegs
                self.maxLegSplits = maxSplits
                // Set default selected method to first non-cash enabled method
                // or cash if nothing else is enabled
                if configured, let first = methods.first {
                    self.paymentMethod = first
                } else {
                    self.paymentMethod = "cash"
                }
            }
        } catch {
            print("[fetchPaymentConfig] ERROR: \(error)")
            // On error default to cash only — don't block the associate
            await MainActor.run {
                self.gatewayConfigured = false
                self.activeGateway = ""
                self.enabledPaymentMethods = ["cash"]
                self.paymentMethod = "cash"
            }
            print("[fetchPaymentConfig] error: \(error)")
        }
    }

    func processPayment(method: String) async {
        guard let order = currentOrder else {
            errorMessage = "No order found. Please place the order first."
            return
        }

        isLoading = true
        errorMessage = nil
        paymentMethod = method

        do {
            let brandId = try await fetchBrandId()

            switch method {
            case "cash":
                struct CashInsert: Encodable {
                    let brand_id: String
                    let sales_order_id: String
                    let amount: Double
                    let tendered: Double
                    let change: Double
                    let note: String?
                    let recorded_by: String
                }

                struct TxInsert: Encodable {
                    let order_id: String
                    let payment_method: String
                    let payment_status: String
                    let amount_paid: Double
                }

                let authId = try await resolveUserId().uuidString
                let change = cashTendered - order.totalAmount
                let payload = CashInsert(
                    brand_id: brandId,
                    sales_order_id: order.id.uuidString,
                    amount: order.totalAmount,
                    tendered: cashTendered,
                    change: change,
                    note: cashNote.isEmpty ? nil : cashNote,
                    recorded_by: authId
                )

                try await SupabaseManager.shared.client
                    .from("cash_records")
                    .insert(payload)
                    .execute()

                // Mark the sales order as completed
                struct OrderStatusUpdate: Encodable { let status: String }
                try? await SupabaseManager.shared.client
                    .from("sales_orders")
                    .update(OrderStatusUpdate(status: "completed"))
                    .eq("order_id", value: order.id.uuidString)
                    .execute()

                struct OrderPaymentUpdate: Encodable {
                    let payment_status: String
                    let amount_paid: Double
                }
                try? await SupabaseManager.shared.client
                    .from("sales_orders")
                    .update(OrderPaymentUpdate(payment_status: "paid", amount_paid: order.totalAmount))
                    .eq("order_id", value: order.id.uuidString)
                    .execute()


                paymentCompleted = true
                isLoading = false
                showPayment = false
                showReceipt = true

            case "upi", "netbanking":
                let createOrderUrl = URL(string: "https://ionszphvxhffqfwlohiv.supabase.co/functions/v1/create-payment-order")!
                var createOrderReq = URLRequest(url: createOrderUrl)
                createOrderReq.httpMethod = "POST"
                createOrderReq.setValue("application/json", forHTTPHeaderField: "Content-Type")

                let accessToken = try await resolveAccessToken()
                createOrderReq.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

                let createOrderBody: [String: Any] = [
                    "sales_order_id": order.id.uuidString,
                    "brand_id": brandId,
                    "method": method
                ]
                createOrderReq.httpBody = try JSONSerialization.data(withJSONObject: createOrderBody)

                let (createOrderData, _) = try await URLSession.shared.data(for: createOrderReq)
                guard let createOrderJson = try JSONSerialization.jsonObject(with: createOrderData) as? [String: Any],
                      let paymentOrderIdStr = createOrderJson["payment_order_id"] as? String,
                      let gatewayOrderIdStr = createOrderJson["gateway_order_id"] as? String,
                      let keyId = createOrderJson["key_id"] as? String else {
                    throw NSError(
                        domain: "PaymentError",
                        code: 1,
                        userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"]
                    )
                }

                paymentOrderId = paymentOrderIdStr
                gatewayOrderId = gatewayOrderIdStr
                checkoutKey = keyId

                if method == "upi" {
                    isLoading = false
                    NotificationCenter.default.post(
                        name: NSNotification.Name("OpenRazorpayCheckout"),
                        object: nil
                    )
                } else {
                    let createSessionUrl = URL(string: "https://ionszphvxhffqfwlohiv.supabase.co/functions/v1/create-payment-session")!
                    var sessionReq = URLRequest(url: createSessionUrl)
                    sessionReq.httpMethod = "POST"
                    sessionReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    sessionReq.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

                    let sessionBody: [String: Any] = ["payment_order_id": paymentOrderIdStr]
                    sessionReq.httpBody = try JSONSerialization.data(withJSONObject: sessionBody)

                    let (sessionData, _) = try await URLSession.shared.data(for: sessionReq)
                    guard let sessionJson = try JSONSerialization.jsonObject(with: sessionData) as? [String: Any],
                          let paymentUrl = sessionJson["payment_url"] as? String,
                          let token = sessionJson["token"] as? String else {
                        throw NSError(
                            domain: "PaymentError",
                            code: 2,
                            userInfo: [NSLocalizedDescriptionKey: "Invalid session response"]
                        )
                    }

                    paymentSessionUrl = paymentUrl
                    paymentSessionToken = token
                    subscribeToPaymentStatus()
                    isLoading = false
                }

            default:
                isLoading = false
                errorMessage = "Unknown payment method"
            }
        } catch {
            isLoading = false
            if error is CancellationError {
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    func verifyPayment(gatewayPaymentId: String, gatewaySignature: String) async {
        guard let paymentOrderId = self.paymentOrderId,
              let gatewayOrderId = self.gatewayOrderId else {
            errorMessage = "Missing payment context."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let verifyUrl = URL(string: "https://ionszphvxhffqfwlohiv.supabase.co/functions/v1/verify-payment")!
            var req = URLRequest(url: verifyUrl)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let accessToken = try await resolveAccessToken()
            req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let body: [String: Any] = [
                "payment_order_id": paymentOrderId,
                "gateway_payment_id": gatewayPaymentId,
                "gateway_order_id": gatewayOrderId,
                "gateway_signature": gatewaySignature
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, _) = try await URLSession.shared.data(for: req)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let success = json["success"] as? Bool,
                  success else {
                throw NSError(
                    domain: "PaymentError",
                    code: 3,
                    userInfo: [NSLocalizedDescriptionKey: "Payment verification failed"]
                )
            }

            // Update the specific leg item that was paid
            let legIdx = self.currentPaymentLegIndex
            let itemIdx = self.currentPaymentItemIndex
            if legIdx < self.billingLegs.count &&
               itemIdx < self.billingLegs[legIdx].items.count {
                self.billingLegs[legIdx].items[itemIdx].existingStatus = "paid"
                let allPaid = self.billingLegs[legIdx].items.allSatisfy { $0.isPaid }
                let anyPaid = self.billingLegs[legIdx].items.contains { $0.isPaid }
                self.billingLegs[legIdx].existingStatus = allPaid
                    ? "paid" : anyPaid ? "partially_paid" : "pending"
            }
            // Store receipt URL
            self.gatewayReceiptUrl = "https://dashboard.razorpay.com/app/payments/\(gatewayPaymentId)"

            paymentCompleted = true
            isLoading = false
            self.successMessage = "Payment verified successfully!"
            
            // Don't show receipt yet — stay in billing view so associate can collect remaining payments
            await self.fetchOrderPaymentSummary(salesOrderId: self.currentOrder?.id.uuidString ?? "")
            
            print("[verifyPayment] SUCCESS: Payment verified for order \(self.currentOrder?.id.uuidString ?? "unknown")")
            
        } catch {
            isLoading = false
            errorMessage = "Payment verification failed: \(error.localizedDescription)"
        }
    }

    func openRazorpayCheckout() {
        guard let keyId = checkoutKey,
              let gatewayOrderId = gatewayOrderId else { return }
              
        let legIdx = currentPaymentLegIndex
        let itemIdx = currentPaymentItemIndex
        
        let amount: Double
        if legIdx >= 0 && legIdx < billingLegs.count &&
           itemIdx >= 0 && itemIdx < billingLegs[legIdx].items.count {
            amount = billingLegs[legIdx].items[itemIdx].amount
        } else {
            // Fallback for remaining balance payments
            amount = remainingPaymentAmount
        }
        
        guard amount > 0 else { return }
        
        razorpay = RazorpayCheckout.initWithKey(keyId, andDelegateWithData: self)

        let options: [String: Any] = [
            "amount": Int(amount * 100),
            "currency": "INR",
            "order_id": gatewayOrderId,
            "name": "RSMS Sales",
            "description": "Payment for Order",
            "prefill": [
                "contact": selectedCustomer?.phone ?? "",
                "email": selectedCustomer?.email ?? ""
            ]
        ]
        
        DispatchQueue.main.async {
            if let topVC = UIApplication.shared.topMostViewController {
                self.razorpay?.open(options, displayController: topVC)
            } else {
                self.razorpay?.open(options)
            }
        }
    }

    func subscribeToPaymentStatus() {
        guard let paymentOrderId else { return }

        Task {
            let channel = SupabaseManager.shared.client.realtimeV2
                .channel("payment-\(paymentOrderId)")
            let updates = channel.postgresChange(
                UpdateAction.self,
                schema: "public",
                table: "payment_orders",
                filter: .eq("id", value: paymentOrderId)
            )
            await channel.subscribe()

            for await update in updates {
                if let status = update.record["status"]?.stringValue, status == "paid" {
                    // Mark order as completed in Supabase
                    if let order = self.currentOrder {
                        struct OrderStatusUpdate: Encodable { let status: String }
                        try? await SupabaseManager.shared.client
                            .from("sales_orders")
                            .update(OrderStatusUpdate(status: "completed"))
                            .eq("order_id", value: order.id.uuidString)
                            .execute()

                        struct OrderPaymentUpdate: Encodable {
                            let payment_status: String
                            let amount_paid: Double
                        }
                        try? await SupabaseManager.shared.client
                            .from("sales_orders")
                            .update(OrderPaymentUpdate(payment_status: "paid", amount_paid: order.totalAmount))
                            .eq("order_id", value: order.id.uuidString)
                            .execute()
                    }
                    await MainActor.run {
                        self.paymentCompleted = true
                        self.showPayment = false
                        self.showReceipt = true
                    }
                    break
                }
            }
        }
    }

    // MARK: - Submit Rating
    // Updates the current order row in sales_orders with rating_value (Int) and
    // rating_feedback (text). NULL is stored when no feedback is provided.
    func submitRating(rating: Double, feedback: String, associateId: UUID? = nil) async {
        guard let orderId = lastPlacedOrder?.id else {
            errorMessage = "No order to attach rating to."
            return
        }

        do {
            struct RatingUpdate: Encodable {
                let rating_value: Int
                let rating_feedback: String?
            }

            let payload = RatingUpdate(
                rating_value: Int(rating.rounded()),
                rating_feedback: feedback.isEmpty ? nil : feedback
            )

            try await client
                .from("sales_orders")
                .update(payload)
                .eq("order_id", value: orderId.uuidString)
                .execute()

            // Update local cache — no re-fetch needed
            await RatingCache.shared.addRating(rating)

            successMessage = "Rating submitted successfully!"
        } catch {
            print("Failed to submit rating: \(error)")
            errorMessage = "Failed to submit rating."
        }
    }

    func resolveUserId() async throws -> UUID {
        let auth = SupabaseManager.shared.client.auth
        if let session = try? await auth.session {
            return session.user.id
        }
        return try await auth.user().id
    }

    func resolveAccessToken() async throws -> String {
        if let session = try? await SupabaseManager.shared.client.auth.session {
            return session.accessToken
        }
        throw NSError(
            domain: "PaymentError",
            code: 401,
            userInfo: [NSLocalizedDescriptionKey: "Session expired. Please sign in again."]
        )
    }

    // MARK: - Billing Helpers

    // Initialize billing legs when billing screen opens
    // maxLegs and maxSplits come from gateway config
    func initializeBillingLegs(
        maxLegs: Int = 2,
        maxSplits: Int = 2
    ) {
        // If the total doesn't match the cart total, we FORCE A RESET
        let currentTotal = billingLegs.reduce(0.0) { $0 + $1.totalAmount }
        let mismatch = abs(currentTotal - cartTotal) > 0.01
        
        if mismatch {
            print("[initializeBillingLegs] Total mismatch detected (Cart: ₹\(cartTotal), Legs: ₹\(currentTotal)). Resetting billing legs.")
            billingLegs = []
        }
        
        // Only initialize if not already set, to prevent reset on re-render
        guard billingLegs.isEmpty else { return }
        
        // Start with one leg covering the full amount
        let defaultItem = BillingLegItem(
            itemNumber: 1,
            amount: cartTotal,
            method: enabledPaymentMethods.first(where: { $0 != "cash" }) ?? "cash",
            tendered: nil,
            note: nil
        )
        let defaultLeg = BillingLeg(
            legNumber: 1,
            dueType: "immediate",
            totalAmount: cartTotal,
            items: [defaultItem]
        )
        billingLegs = [defaultLeg]
    }

    // Add a new leg (up to maxLegs)
    func addBillingLeg(maxLegs: Int) {
        guard billingLegs.count < maxLegs else { return }
        let legNumber = billingLegs.count + 1
        // Remaining amount not covered by existing legs
        let covered = billingLegs.reduce(0.0) { $0 + $1.totalAmount }
        let remaining = max(0, cartTotal - covered)
        let newLeg = BillingLeg(
            legNumber: legNumber,
            dueType: "on_delivery",
            totalAmount: remaining,
            items: [BillingLegItem(
                itemNumber: 1,
                amount: remaining,
                method: "cash",
                tendered: nil,
                note: nil
            )]
        )
        billingLegs.append(newLeg)
    }

    // Remove a leg
    func removeBillingLeg(at index: Int) {
        guard billingLegs.count > 1 else { return }
        let removedAmount = billingLegs[index].totalAmount
        billingLegs.remove(at: index)
        // Renumber legs
        for i in billingLegs.indices {
            billingLegs[i].legNumber = i + 1
        }
        // Add removed amount to Leg 1 (index 0) and sync its splits
        billingLegs[0].totalAmount += removedAmount
        syncSplitsInLeg(at: 0, in: &billingLegs)
    }

    // Add split item to a leg
    func addSplitItem(to legIndex: Int, maxSplits: Int) {
        guard legIndex < billingLegs.count,
              billingLegs[legIndex].items.count < maxSplits else { return }
        let itemNumber = billingLegs[legIndex].items.count + 1
        let covered = billingLegs[legIndex].items.reduce(0.0) { $0 + $1.amount }
        let remaining = max(0, billingLegs[legIndex].totalAmount - covered)
        let newItem = BillingLegItem(
            itemNumber: itemNumber,
            amount: remaining,
            method: "cash",
            tendered: nil,
            note: nil
        )
        billingLegs[legIndex].items.append(newItem)
    }

    // Remove split item from a leg
    func removeSplitItem(from legIndex: Int, itemIndex: Int) {
        guard legIndex < billingLegs.count,
              billingLegs[legIndex].items.count > 1 else { return }
        billingLegs[legIndex].items.remove(at: itemIndex)
        // Renumber items
        for i in billingLegs[legIndex].items.indices {
            billingLegs[legIndex].items[i].itemNumber = i + 1
        }
        // Balance the leg's remaining splits to absorb the deleted amount
        syncSplitsInLeg(at: legIndex, in: &billingLegs)
    }

    // Update a specific leg's amount and balance others
    func updateLegAmount(at index: Int, to newValue: Double) {
        guard index < billingLegs.count else { return }
        print("[updateLegAmount] index: \(index), newValue: \(newValue), cartTotal: \(cartTotal)")
        
        var updatedLegs = billingLegs
        updatedLegs[index].totalAmount = newValue
        
        if updatedLegs.count > 1 {
            // Principle: Leg 1 (index 0) is the master adjuster for everyone else
            if index != 0 {
                // Editing Leg 2+ -> Adjust Leg 1
                let targetIdx = 0
                var othersSum = newValue
                for i in 0..<updatedLegs.count {
                    if i != index && i != targetIdx {
                        othersSum += updatedLegs[i].totalAmount
                    }
                }
                updatedLegs[targetIdx].totalAmount = max(0, cartTotal - othersSum)
                syncSplitsInLeg(at: targetIdx, in: &updatedLegs)
            } else {
                // Editing Leg 1 (Principal) -> Adjust the LAST leg
                let targetIdx = updatedLegs.count - 1
                var othersSum = newValue
                for i in 0..<updatedLegs.count {
                    if i != index && i != targetIdx {
                        othersSum += updatedLegs[i].totalAmount
                    }
                }
                updatedLegs[targetIdx].totalAmount = max(0, cartTotal - othersSum)
                syncSplitsInLeg(at: targetIdx, in: &updatedLegs)
            }
        }
        
        // Sync splits for the current edited leg
        syncSplitsInLeg(at: index, in: &updatedLegs)
        self.billingLegs = updatedLegs
    }

    // Update a specific split's amount and balance others within that leg
    func updateSplitAmount(legIndex: Int, itemIndex: Int, to newValue: Double) {
        guard legIndex < billingLegs.count,
              itemIndex < billingLegs[legIndex].items.count else { return }
        
        print("[updateSplitAmount] leg: \(legIndex), item: \(itemIndex), newValue: \(newValue)")
        var updatedLegs = billingLegs
        updatedLegs[legIndex].items[itemIndex].amount = newValue
        
        if legIndex == 0 {
            // Special case for Leg 1 (Principal): Splits balance AGAINST EACH OTHER
            let leg = updatedLegs[0]
            if leg.items.count > 1 {
                // Find a target item to balance against. It must be PENDING and NOT the one being edited.
                if let targetIdx = leg.items.firstIndex(where: { !$0.isPaid && $0.id != leg.items[itemIndex].id }) {
                    var othersSum = newValue
                    for i in 0..<leg.items.count {
                        if i != itemIndex && i != targetIdx { othersSum += leg.items[i].amount }
                    }
                    updatedLegs[0].items[targetIdx].amount = max(0, leg.totalAmount - othersSum)
                }
            }
            self.billingLegs = updatedLegs
        } else {
            // For any other leg: Split edits update the LEG TOTAL, which then deducts from LEG 1
            let newLegTotal = updatedLegs[legIndex].items.reduce(0.0) { $0 + $1.amount }
            self.billingLegs = updatedLegs // commit local split change first
            updateLegAmount(at: legIndex, to: newLegTotal)
        }
    }

    private func syncSplitsInLeg(at index: Int, in legs: inout [BillingLeg]) {
        guard index < legs.count else { return }
        let leg = legs[index]
        
        // Find the first pending item to act as the counterbalance
        let targetItemIdx = leg.items.firstIndex(where: { !$0.isPaid }) ?? (leg.items.count - 1)
        
        var otherSum = 0.0
        for i in 0..<leg.items.count {
            if i != targetItemIdx {
                otherSum += leg.items[i].amount
            }
        }
        
        legs[index].items[targetItemIdx].amount = max(0, leg.totalAmount - otherSum)
    }

    // Auto-balance billing legs and splits
    func autoBalanceBilling() {
        var updatedLegs = billingLegs
        for legIdx in updatedLegs.indices {
            syncSplitsInLeg(at: legIdx, in: &updatedLegs)
        }
        
        if updatedLegs.count > 1 {
            var allButLastLegSum = 0.0
            for i in 0..<(updatedLegs.count - 1) {
                allButLastLegSum += updatedLegs[i].totalAmount
            }
            let newLastLegTotal = max(0, cartTotal - allButLastLegSum)
            updatedLegs[updatedLegs.count - 1].totalAmount = newLastLegTotal
            syncSplitsInLeg(at: updatedLegs.count - 1, in: &updatedLegs)
        } else if updatedLegs.count == 1 {
            updatedLegs[0].totalAmount = cartTotal
            syncSplitsInLeg(at: 0, in: &updatedLegs)
        }
        self.billingLegs = updatedLegs
    }

    // Fetch payment summary for an order or appointment
    func fetchOrderPaymentSummary(salesOrderId: String? = nil, appointmentId: String? = nil) async {
        isLoadingPaymentSummary = true
        defer { isLoadingPaymentSummary = false }

        do {
            let brandId = try await fetchBrandId()
            let session = try await SupabaseManager.shared.client.auth.session

            let url = URL(string: "https://ionszphvxhffqfwlohiv.supabase.co/functions/v1/get-order-payment-summary")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(session.accessToken)",
                         forHTTPHeaderField: "Authorization")
            
            var body: [String: Any] = ["brand_id": brandId]
            if let orderId = salesOrderId { body["sales_order_id"] = orderId }
            if let apptId = appointmentId { body["appointment_id"] = apptId }
            
            req.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, _) = try await URLSession.shared.data(for: req)
            guard let json = try JSONSerialization.jsonObject(with: data)
                    as? [String: Any],
                  let orderJson = json["order"] as? [String: Any],
                  let gwJson = json["gateway_config"] as? [String: Any]
            else { return }

            let legsJson = json["legs"] as? [[String: Any]] ?? []
            var legs: [PaymentLegRecord] = []

            for legJson in legsJson {
                let itemsJson = legJson["items"] as? [[String: Any]] ?? []
                var items: [PaymentLegItemRecord] = []
                for itemJson in itemsJson {
                    let item = PaymentLegItemRecord(
                        id: UUID(uuidString: itemJson["id"] as? String ?? "") ?? UUID(),
                        itemNumber: itemJson["item_number"] as? Int ?? 0,
                        amount: (itemJson["amount"] as? NSNumber)?.doubleValue ?? 0,
                        method: itemJson["method"] as? String ?? "cash",
                        status: itemJson["status"] as? String ?? "pending",
                        collectedAt: itemJson["collected_at"] as? String,
                        note: itemJson["note"] as? String,
                        receiptUrl: itemJson["receipt_url"] as? String
                    )
                    items.append(item)
                }
                let leg = PaymentLegRecord(
                    id: UUID(uuidString: legJson["id"] as? String ?? "") ?? UUID(),
                    legNumber: legJson["leg_number"] as? Int ?? 0,
                    dueType: legJson["due_type"] as? String ?? "immediate",
                    totalAmount: (legJson["total_amount"] as? NSNumber)?.doubleValue ?? 0,
                    amountPaid: (legJson["amount_paid"] as? NSNumber)?.doubleValue ?? 0,
                    status: legJson["status"] as? String ?? "pending",
                    collectedAt: legJson["collected_at"] as? String,
                    items: items
                )
                legs.append(leg)
            }

            let summary = OrderPaymentSummary(
                orderId: orderJson["id"] as? String ?? "",
                totalAmount: (orderJson["total_amount"] as? NSNumber)?.doubleValue ?? 0,
                amountPaid: (orderJson["amount_paid"] as? NSNumber)?.doubleValue ?? 0,
                remaining: (orderJson["remaining"] as? NSNumber)?.doubleValue ?? 0,
                paymentStatus: orderJson["payment_status"] as? String ?? "unpaid",
                isFullyPaid: orderJson["is_fully_paid"] as? Bool ?? false,
                legs: legs,
                maxPaymentLegs: gwJson["max_payment_legs"] as? Int ?? 2,
                maxLegSplits: gwJson["max_leg_splits"] as? Int ?? 2,
                enabledMethods: gwJson["enabled_methods"] as? [String] ?? ["cash"]
            )

            await MainActor.run {
                self.orderPaymentSummary = summary
                // If we are currently in the billing configuration flow, 
                // sync the summary back to our editable legs
                self.syncBillingLegsWithSummary()
            }
        } catch {
            print("[fetchOrderPaymentSummary] error: \(error)")
        }
    }

    // Convert the read-only summary from Supabase into editable legs
    func syncBillingLegsWithSummary() {
        guard let summary = orderPaymentSummary, !summary.legs.isEmpty else { return }
        
        billingLegs = summary.legs.map { legRec in
            let items = legRec.items.map { itemRec in
                BillingLegItem(
                    itemNumber: itemRec.itemNumber,
                    amount: itemRec.amount,
                    method: itemRec.method,
                    tendered: nil,
                    note: itemRec.note,
                    existingStatus: itemRec.status,
                    existingItemId: itemRec.id.uuidString
                )
            }
            return BillingLeg(
                legNumber: legRec.legNumber,
                dueType: legRec.dueType,
                totalAmount: legRec.totalAmount,
                items: items,
                existingStatus: legRec.status,
                existingLegId: legRec.id.uuidString
            )
        }
    }

    func loadExistingBillingLegs(salesOrderId: String) async {
        await fetchOrderPaymentSummary(salesOrderId: salesOrderId)
        
        guard let summary = orderPaymentSummary, !summary.legs.isEmpty else {
            initializeBillingLegs()
            return
        }
        
        // syncBillingLegsWithSummary already handles the mapping
    }

    func saveBillingDraft(appointmentId: UUID?) async {
        guard let order = currentOrder else { return }

        // Only save if there are legs configured
        guard !billingLegs.isEmpty else { return }

        // Only save if there are unsaved (new) legs
        let hasNewLegs = billingLegs.contains { $0.isNew }
        guard hasNewLegs else { return }

        do {
            let brandId = try await fetchBrandId()
            let session = try await SupabaseManager.shared.client.auth.session
            let authId = session.user.id.uuidString

            // Build legs payload — only include new legs
            var legsPayload: [[String: Any]] = []
            for leg in billingLegs {
                var itemsPayload: [[String: Any]] = []
                for item in leg.items {
                    var itemDict: [String: Any] = [
                        "item_number": item.itemNumber,
                        "amount": item.amount,
                        "method": item.method,
                    ]
                    if let note = item.note {
                        itemDict["note"] = note
                    }
                    itemsPayload.append(itemDict)
                }
                legsPayload.append([
                    "leg_number": leg.legNumber,
                    "due_type": leg.dueType,
                    "total_amount": leg.totalAmount,
                    "items": itemsPayload
                ])
            }

            var body: [String: Any] = [
                "brand_id": brandId,
                "sales_order_id": order.id.uuidString,
                "recorded_by": authId,
                "action": "draft",
                "legs": legsPayload
            ]
            if let apptId = appointmentId {
                body["appointment_id"] = apptId.uuidString
            }

            let url = URL(string: "https://ionszphvxhffqfwlohiv.supabase.co/functions/v1/create-billing")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(session.accessToken)",
                         forHTTPHeaderField: "Authorization")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (_, _) = try await URLSession.shared.data(for: req)
            // Silent draft save

        } catch {
            print("[saveBillingDraft] error: \(error)")
        }
    }

    // Submit billing to create-billing Edge Function
    func submitBilling(
        appointmentId: UUID?,
        action: String, // "save" or "mark_as_paid"
        orderStore: SharedOrderStore
    ) async {
        isLoading = true
        errorMessage = nil

        // If no order exists yet (first time clicking save/confirm), create it now
        if currentOrder == nil {
            await placeOrder(orderStore: orderStore)
        }

        guard let order = currentOrder else {
            isLoading = false
            errorMessage = "Could not create order. Please try again."
            return
        }

        do {
            let brandId = try await fetchBrandId()
            let session = try await SupabaseManager.shared.client.auth.session
            let authId = session.user.id.uuidString

            // Build legs payload
            var legsPayload: [[String: Any]] = []
            for leg in billingLegs {
                var itemsPayload: [[String: Any]] = []
                for item in leg.items {
                    var itemDict: [String: Any] = [
                        "item_number": item.itemNumber,
                        "amount": item.amount,
                        "method": item.method,
                    ]
                    if let tendered = item.tendered {
                        itemDict["tendered"] = tendered
                    }
                    if let note = item.note {
                        itemDict["note"] = note
                    }
                    itemsPayload.append(itemDict)
                }
                var legDict: [String: Any] = [
                    "leg_number": leg.legNumber,
                    "due_type": leg.dueType,
                    "total_amount": leg.totalAmount,
                    "items": itemsPayload
                ]
                legsPayload.append(legDict)
            }

            var body: [String: Any] = [
                "brand_id": brandId,
                "sales_order_id": order.id.uuidString,
                "recorded_by": authId,
                "action": action,
                "legs": legsPayload
            ]
            // Only link appointment during final payment, not during "Save Billing Plan"
            if action != "save", let apptId = appointmentId {
                body["appointment_id"] = apptId.uuidString
            }

            if let bodyData = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted),
               let bodyString = String(data: bodyData, encoding: .utf8) {
                print("[submitBilling] REQUEST BODY: \(bodyString)")
            }

            let url = URL(string: "https://ionszphvxhffqfwlohiv.supabase.co/functions/v1/create-billing")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(session.accessToken)",
                         forHTTPHeaderField: "Authorization")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, _) = try await URLSession.shared.data(for: req)
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("[submitBilling] RAW RESPONSE: \(responseString)")
            }

            guard let json = try JSONSerialization.jsonObject(with: data)
                    as? [String: Any] else {
                throw NSError(domain: "BillingError", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid response from server"])
            }

            if let error = json["error"] as? String {
                throw NSError(domain: "BillingError", code: 2,
                    userInfo: [NSLocalizedDescriptionKey: error])
            }

            // Check for pending gateway payments that need SDK
            let pendingGateway = json["pending_gateway_payments"] as? [[String: Any]] ?? []

            if let first = pendingGateway.first,
               let gwOrderId = first["gateway_order_id"] as? String,
               let keyId = first["key_id"] as? String,
               let poId = first["payment_order_id"] as? String {
                // Store details and open Razorpay SDK
                self.gatewayOrderId = gwOrderId
                self.checkoutKey = keyId
                self.paymentOrderId = poId
                isLoading = false
                // Only open Razorpay if this wasn't a simple draft save
                if action != "draft" {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("OpenRazorpayCheckout"),
                        object: nil
                    )
                } else {
                    // It was a draft save, just show success
                    isLoading = false
                    NotificationCenter.default.post(
                        name: NSNotification.Name("RefreshSalesAssociateDashboard"),
                        object: nil
                    )
                }
            } else {
                // All cash — mark complete
                let orderStatus = json["order_payment_status"] as? String ?? "unpaid"
                paymentCompleted = orderStatus == "paid"
                isLoading = false
                showBilling = false
                if action == "mark_as_paid" {
                    showReceipt = true
                    
                    // If successfully paid/checked out, delete the appointment
                    if let apptId = appointmentId {
                        Task {
                            await completeAppointment(id: apptId)
                        }
                    }
                }
                NotificationCenter.default.post(
                    name: NSNotification.Name("RefreshSalesAssociateDashboard"),
                    object: nil
                )
            }
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Appointment Cleanup
    
    /// Marks an appointment as 'completed' in Supabase. Called after successful checkout.
    func completeAppointment(id: UUID) async {
        print("[completeAppointment] Marking appointment as completed: \(id)")
        do {
            struct StatusUpdate: Encodable { let status: String }
            try await client
                .from("appointments")
                .update(StatusUpdate(status: "completed"))
                .eq("id", value: id.uuidString)
                .execute()
            
            print("[completeAppointment] Successfully completed appointment: \(id)")
            
            // Post notification to remove locally for instant UI feedback
            await MainActor.run {
                NotificationCenter.default.post(
                    name: NSNotification.Name("RemoveAppointmentLocally"),
                    object: id
                )
                NotificationCenter.default.post(
                    name: NSNotification.Name("RefreshAppointmentsList"),
                    object: nil
                )
            }
        } catch {
            print("[completeAppointment] Failed: \(error)")
        }
    }
}

extension AssociateSalesViewModel: RazorpayPaymentCompletionProtocolWithData {
    func onPaymentError(_ code: Int32, description str: String, andData response: [AnyHashable: Any]?) {
        Task { @MainActor in
            self.isLoading = false
            self.errorMessage = "Payment failed: \(str)"
        }
    }

    func onPaymentSuccess(_ payment_id: String, andData response: [AnyHashable: Any]?) {
        let signature = response?["razorpay_signature"] as? String ?? ""
        Task { @MainActor in
            await self.verifyPayment(
                gatewayPaymentId: payment_id,
                gatewaySignature: signature
            )
        }
    }

    func collectCashItem(
        legIndex: Int,
        itemIndex: Int,
        appointmentId: UUID?
    ) async {
        guard legIndex < billingLegs.count,
              itemIndex < billingLegs[legIndex].items.count,
              let order = currentOrder else { return }

        let item = billingLegs[legIndex].items[itemIndex]
        guard item.method == "cash" else { return }

        isLoading = true
        errorMessage = nil

        do {
            let brandId = try await fetchBrandId()
            let authId = try await resolveUserId().uuidString
            let accessToken = try await resolveAccessToken()

            // Step 1: If item has no DB ID, save the billing plan first
            if item.isNew {
                await submitBilling(
                    appointmentId: appointmentId,
                    action: "draft",
                    orderStore: SharedOrderStore()
                )
                // Refresh to get DB IDs
                await fetchOrderPaymentSummary(salesOrderId: order.id.uuidString)
            }

            // Get the updated item ID after potential save
            let itemId = billingLegs[legIndex].items[itemIndex].existingItemId
            let legId = billingLegs[legIndex].existingLegId

            guard let itemId = itemId, let legId = legId else {
                errorMessage = "Could not find payment record. Please save the billing plan first."
                isLoading = false
                return
            }

            let tendered = item.tendered ?? item.amount

            let url = URL(string: "https://ionszphvxhffqfwlohiv.supabase.co/functions/v1/collect-remaining-payment")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let body: [String: Any] = [
                "brand_id": brandId,
                "sales_order_id": order.id.uuidString,
                "payment_leg_item_id": itemId,
                "payment_leg_id": legId,
                "recorded_by": authId,
                "method": "cash",
                "tendered": tendered,
            ]
            if let bodyData = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted),
               let bodyString = String(data: bodyData, encoding: .utf8) {
                print("[collect-cash] REQUEST BODY: \(bodyString)")
            }
            req.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, _) = try await URLSession.shared.data(for: req)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw NSError(domain: "BillingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }

            if let error = json["error"] as? String {
                throw NSError(domain: "BillingError", code: 2, userInfo: [NSLocalizedDescriptionKey: error])
            }

            // Mark item as paid locally
            billingLegs[legIndex].items[itemIndex].existingStatus = "paid"

            // Update leg status locally
            let allItemsPaid = billingLegs[legIndex].items.allSatisfy { $0.isPaid }
            let anyItemPaid = billingLegs[legIndex].items.contains { $0.isPaid }
            billingLegs[legIndex].existingStatus = allItemsPaid ? "paid" : anyItemPaid ? "partially_paid" : "pending"

            isLoading = false
            await fetchOrderPaymentSummary(salesOrderId: order.id.uuidString)

        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
        }
    }

    func initiateGatewayPaymentForItem(
        legIndex: Int,
        itemIndex: Int,
        appointmentId: UUID?
    ) async {
        guard legIndex < billingLegs.count,
              itemIndex < billingLegs[legIndex].items.count,
              let order = currentOrder else { return }

        let item = billingLegs[legIndex].items[itemIndex]
        guard item.method == "online" || item.method == "upi" || item.method == "netbanking" else { return }

        isLoading = true
        errorMessage = nil

        do {
            let brandId = try await fetchBrandId()
            let authId = try await resolveUserId().uuidString
            let accessToken = try await resolveAccessToken()

            // Step 1: If item has no DB ID, save billing plan first
            if item.isNew {
                await submitBilling(
                    appointmentId: appointmentId,
                    action: "draft",
                    orderStore: SharedOrderStore()
                )
                await fetchOrderPaymentSummary(salesOrderId: order.id.uuidString)
            }

            let itemId = billingLegs[legIndex].items[itemIndex].existingItemId
            let legId = billingLegs[legIndex].existingLegId

            guard let itemId = itemId, let legId = legId else {
                errorMessage = "Could not find payment record."
                isLoading = false
                return
            }

            let url = URL(string: "https://ionszphvxhffqfwlohiv.supabase.co/functions/v1/collect-remaining-payment")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let body: [String: Any] = [
                "brand_id": brandId,
                "sales_order_id": order.id.uuidString,
                "payment_leg_item_id": itemId,
                "payment_leg_id": legId,
                "recorded_by": authId,
                "method": item.method,
            ]
            if let bodyData = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted),
               let bodyString = String(data: bodyData, encoding: .utf8) {
                print("[collect-remaining-payment] REQUEST BODY: \(bodyString)")
            }
            req.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, _) = try await URLSession.shared.data(for: req)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw NSError(domain: "BillingError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }

            if let error = json["error"] as? String {
                throw NSError(domain: "BillingError", code: 2, userInfo: [NSLocalizedDescriptionKey: error])
            }

            // Gateway requires SDK
            let requiresSDK = json["requires_sdk"] as? Bool ?? false
            if requiresSDK,
               let gwOrderId = json["gateway_order_id"] as? String,
               let keyId = json["key_id"] as? String,
               let poId = json["payment_order_id"] as? String {
                self.gatewayOrderId = gwOrderId
                self.checkoutKey = keyId
                self.paymentOrderId = poId
                self.currentPaymentLegIndex = legIndex
                self.currentPaymentItemIndex = itemIndex
                isLoading = false
                
                let gateway = json["gateway"] as? String ?? "razorpay"
                if gateway == "razorpay" {
                    NotificationCenter.default.post(name: NSNotification.Name("OpenRazorpayCheckout"), object: nil)
                } else if gateway == "cashfree" {
                    self.cashfreeSessionId = json["payment_session_id"] as? String
                    NotificationCenter.default.post(name: NSNotification.Name("OpenCashfreeCheckout"), object: nil)
                } else if gateway == "payu" {
                    self.payuHash = json["payu_hash"] as? String
                    NotificationCenter.default.post(name: NSNotification.Name("OpenPayUCheckout"), object: nil)
                }
            } else {
                isLoading = false
            }

        } catch {
            let brandId = (try? await fetchBrandId()) ?? "unknown"
            let msg = error.localizedDescription
            if msg.lowercased().contains("vault") {
                errorMessage = "Razorpay Vault Error: Credentials not found for Brand \(brandId). Please RE-SAVE in Corporate Admin settings."
            } else {
                errorMessage = msg + " [Brand: \(brandId)]"
            }
            isLoading = false
        }
    }

    func checkoutAppointment(
        appointmentId: UUID,
        orderStore: SharedOrderStore,
        appointmentsVM: AppointmentsViewModel? = nil,
        onComplete: @escaping () -> Void
    ) async {
        guard let order = currentOrder else {
            errorMessage = "No order found."
            return
        }

        // Validate all immediate legs are paid
        let unpaidImmediateItems = billingLegs
            .filter { $0.dueType == "immediate" }
            .flatMap { $0.items }
            .filter { !$0.isPaid }

        if !unpaidImmediateItems.isEmpty {
            errorMessage = "Complete all immediate payments before checkout."
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            let brandId = try await fetchBrandId()
            let authId = try await resolveUserId().uuidString
            let accessToken = try await resolveAccessToken()
            
            // Step 1: Save the full billing plan (legs/splits) first
            // to ensure backend has a record of pending payments
            await submitBilling(
                appointmentId: appointmentId,
                action: "draft",
                orderStore: orderStore
            )

            let url = URL(string: "https://ionszphvxhffqfwlohiv.supabase.co/functions/v1/checkout-appointment")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let body: [String: Any] = [
                "appointment_id": appointmentId.uuidString,
                "sales_order_id": order.id.uuidString,
                "brand_id": brandId,
                "recorded_by": authId,
            ]
            req.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, _) = try await URLSession.shared.data(for: req)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw NSError(domain: "CheckoutError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }

            if let error = json["error"] as? String {
                throw NSError(domain: "CheckoutError", code: 2, userInfo: [NSLocalizedDescriptionKey: error])
            }

            isLoading = false
            showBilling = false

            if let placed = lastPlacedOrder {
                orderStore.addOrder(placed)
            }

            if let avm = appointmentsVM {
                await avm.deleteAppointment(id: appointmentId)
            }

            resetOrderContext()
            onComplete()

        } catch {
            let brandId = (try? await fetchBrandId()) ?? "unknown"
            let msg = error.localizedDescription
            if msg.lowercased().contains("vault") {
                errorMessage = "Razorpay Vault Error: Credentials not found for Brand \(brandId). Please RE-SAVE in Corporate Admin settings."
            } else {
                errorMessage = msg + " [Brand: \(brandId)]"
            }
            isLoading = false
        }
    }
}


extension UIApplication {
    var topMostViewController: UIViewController? {
        guard let windowScene = connectedScenes.first(where: { $0.activationState == .foregroundActive || $0.activationState == .foregroundInactive }) as? UIWindowScene,
              let rootViewController = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            return nil
        }
        
        var topController = rootViewController
        
        while let presentedViewController = topController.presentedViewController {
            topController = presentedViewController
        }
        
        if let navigationController = topController as? UINavigationController {
            topController = navigationController.visibleViewController ?? topController
        } else if let tabBarController = topController as? UITabBarController {
            if let selected = tabBarController.selectedViewController {
                topController = selected
            }
        }
        
        return topController
    }
}
