import SwiftUI
import Supabase
import PostgREST
import Combine

@MainActor
class AssociateSalesViewModel: ObservableObject {

    private let client = SupabaseManager.shared.client

    // MARK: Customer
    @Published var customers: [Customer] = []
    @Published var selectedCustomer: Customer?
    @Published var customerSearch = ""

    // MARK: Cart
    @Published var cartItems: [CartItem] = []

    // MARK: Products
    @Published var products: [Product] = []
    @Published var productSearch = ""

    // MARK: Order
    @Published var currentOrder: SalesOrder?
    @Published var currentTransaction: Transaction?
    @Published var lastPlacedOrder: PlacedOrder?

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
        } catch {
            errorMessage = "Could not load products."
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

        // MARK: Persist to Supabase (awaited — order must exist before rating can reference it)
        do {
            // Look up the associate's store_id — required by the DB trigger
            struct SAStoreRow: Decodable { let store_id: UUID }
            let saRows: [SAStoreRow] = try await SupabaseManager.shared.client
                .from("sales_associates")
                .select("store_id")
                .eq("user_id", value: associateId.uuidString)
                .limit(1)
                .execute()
                .value
            let storeId = saRows.first?.store_id

            struct SOInsert: Encodable {
                let order_id: UUID; let customer_id: UUID
                let sales_associate_id: UUID; let total_amount: Double
                let store_id: UUID?
            }
            struct OIInsert: Encodable {
                let order_id: UUID; let product_id: UUID
                let quantity: Int; let price_at_purchase: Double
            }

            let order: SalesOrder = try await SupabaseManager.shared.client
                .from("sales_orders")
                .insert(SOInsert(
                    order_id: newId,
                    customer_id: customer.id,
                    sales_associate_id: associateId,
                    total_amount: total,
                    store_id: storeId
                ))
                .select().single().execute().value


            self.currentOrder = order

            let items = snapshot.map {
                OIInsert(order_id: order.id, product_id: $0.product.id,
                         quantity: $0.quantity, price_at_purchase: $0.product.price)
            }
            try await SupabaseManager.shared.client
                .from("order_items").insert(items).execute()

            // Delete the appointment session if this order was started from one
            if let apptId = appointmentId, let avm = appointmentsVM {
                await avm.deleteAppointment(id: apptId)
            }

            // Receipt row — fire-and-forget
            Task {
                struct RcptInsert: Encodable { let order_id: UUID }
                try? await SupabaseManager.shared.client
                    .from("receipts").insert(RcptInsert(order_id: order.id)).execute()
            }
        } catch {
            print("[placeOrder] DB save failed: \(error)")
            self.errorMessage = "Order could not be saved. Please try again."
            self.isLoading = false
            return
        }

        // MARK: Show receipt
        let placed = PlacedOrder(
            id: newId, orderNumber: orderNum,
            customer: customer, items: snapshot,
            totalAmount: total, status: "placed",
            createdAt: Date(), associateName: associateName
        )
        lastPlacedOrder = placed
        orderStore.addOrder(placed)
        isLoading = false
        showReceipt = true

        NotificationCenter.default.post(
            name: NSNotification.Name("RefreshSalesAssociateDashboard"), object: nil)
    }

    func processPayment(method: String) async {}

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
}
