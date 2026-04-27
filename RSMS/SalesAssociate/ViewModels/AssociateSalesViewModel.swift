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
    @Published var cashTendered: Double = 0
    @Published var cashNote: String = ""
    @Published var paymentMethod: String = "upi"
    /// Set to true after payment is confirmed (cash record saved or Razorpay verified)
    @Published var paymentCompleted: Bool = false

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
    }

    // MARK: - Fetch Customers
    func fetchCustomers(search: String = "") async {
        do {
            let all: [Customer] = try await client
                .from("customers")
                .select()
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
            }
            let payload = CustomerInsert(name: name, phone: phone.isEmpty ? nil : phone, email: email.isEmpty ? nil : email, gender: gender?.isEmpty == false ? gender : nil, date_of_birth: dateOfBirth?.isEmpty == false ? dateOfBirth : nil, address: address?.isEmpty == false ? address : nil, nationality: nationality?.isEmpty == false ? nationality : nil, notes: notes?.isEmpty == false ? notes : nil, customer_category: category)

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
            return false
        }
    }

    // MARK: - Fetch Products
    func fetchProducts(search: String = "") async {
        do {
            let all: [Product] = try await client
                .from("products")
                .select()
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
                associateName = session.user.userMetadata["full_name"]?.value as? String
                    ?? session.user.email
                    ?? "Sales Associate"
            } else {
                let user = try await authClient.user()
                associateId = user.id
                associateName = user.userMetadata["full_name"]?.value as? String
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
                    store_id: storeId
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

            // Delete the appointment session if this order was started from one
            if let apptId = appointmentId, let avm = appointmentsVM {
                await avm.deleteAppointment(id: apptId)
            }

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
        showReceipt = true

        NotificationCenter.default.post(
            name: NSNotification.Name("RefreshSalesAssociateDashboard"), object: nil)
    }

    private func friendlyOrderSaveError(_ error: Error) -> String {
        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        if !message.isEmpty, message != "The operation couldn’t be completed." {
            return message
        }
        return String(describing: error)
    }

    private func fetchBrandId() async throws -> String {
        let authId = try await resolveUserId().uuidString

        // Sales Associates don't have brand_id in users — resolve via store
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
        return brandId.uuidString
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
        guard let paymentOrderId,
              let gatewayOrderId else { return }

        isLoading = true
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

            // Mark the sales order as completed in Supabase
            if let order = currentOrder {
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

            paymentCompleted = true
            isLoading = false
            showPayment = false
            showReceipt = true
        } catch {
            isLoading = false
            if error is CancellationError {
                return
            }
            errorMessage = error.localizedDescription
        }
    }

    func openRazorpayCheckout() {
        guard let keyId = checkoutKey,
              let gatewayOrderId,
              let order = currentOrder else { return }

        razorpay = RazorpayCheckout.initWithKey(keyId, andDelegateWithData: self)

        let options: [String: Any] = [
            "amount": Int(order.totalAmount * 100),
            "currency": "INR",
            "order_id": gatewayOrderId,
            "name": "Your Shop",
            "description": "Payment for Order",
            "prefill": [
                "contact": selectedCustomer?.phone ?? "",
                "email": selectedCustomer?.email ?? ""
            ]
        ]
        razorpay?.open(options)
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

    private func resolveUserId() async throws -> UUID {
        let auth = SupabaseManager.shared.client.auth
        if let session = try? await auth.session {
            return session.user.id
        }
        return try await auth.user().id
    }

    private func resolveAccessToken() async throws -> String {
        if let session = try? await SupabaseManager.shared.client.auth.session {
            return session.accessToken
        }
        throw NSError(
            domain: "PaymentError",
            code: 401,
            userInfo: [NSLocalizedDescriptionKey: "Session expired. Please sign in again."]
        )
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
}
