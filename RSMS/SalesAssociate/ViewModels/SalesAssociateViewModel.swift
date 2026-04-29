import Foundation
import Combine
import Supabase
import PostgREST

@MainActor
final class SalesAssociateViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    @Published var todaySalesAmount: Double = 0
    @Published var todayOrderCount: Int = 0
    @Published var customersCount: Int = 0

    /// Tracks whether RatingCache has been seeded from Supabase already.
    /// Once true, new submissions update the cache locally — no re-fetch.
    private var ratingCacheSeeded = false

    @Published var recentOrders: [SAOrder] = []
    @Published var customers: [Customer] = []
    @Published var catalog: [Product] = []
    @Published var trendingProducts: [TrendingProduct] = []


    private let client = SupabaseManager.shared.client

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            // Resolve auth — catch cancellation separately so it doesn't surface as an error
            let userId: UUID
            do {
                userId = try await resolveUserId()
            } catch is CancellationError {
                return  // silently abort — SwiftUI cancelled the task
            } catch {
                errorMessage = "Session expired. Please sign in again."
                return
            }

            let scopedStoreIds: [String]
            do {
                scopedStoreIds = try await resolveCurrentAssociateBrandStoreIds(userId: userId)
            } catch is CancellationError {
                return
            } catch {
                errorMessage = "Unable to resolve order scope for your brand."
                return
            }

            if scopedStoreIds.isEmpty {
                recentOrders = []
                todayOrderCount = 0
                todaySalesAmount = 0
                errorMessage = nil
                return
            }

            async let ordersTask: [SAOrder] = client
                .from("sales_orders")
                .select("order_id,total_amount,status,created_at,customers(name)")
                .eq("sales_associate_id", value: userId.uuidString)  // ← must be String
                .in("store_id", values: scopedStoreIds)
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value

            async let ratingsTask: [SARating] = SupabaseManager.shared.serviceRoleClient
                .from("order_feedback")
                .select("order_id, rating")
                .eq("sales_associate_id", value: userId.uuidString)
                .execute()
                .value

            async let customersTask: [Customer] = client
                .from("customers")
                .select("*")
                .order("created_at", ascending: false)
                .limit(50)
                .execute()
                .value

            async let catalogTask: [Product] = client
                .from("products")
                .select("product_id,name,brand_id,category,price,sku,making_price,image_url,is_active")
                .eq("brand_id", value: try await resolveBrandId(userId: userId))
                .limit(50)
                .execute()
                .value

            let orders: [SAOrder]
            let ratings: [SARating]
            let customers: [Customer]
            do {
                orders    = try await ordersTask
                ratings   = try await ratingsTask
                customers = try await customersTask
            } catch is CancellationError {
                return  // silently abort
            }

            var fetchedCatalog: [Product] = []
            do {
                fetchedCatalog = try await catalogTask
            } catch is CancellationError {
                return
            } catch {
                print("Failed to fetch catalog on refresh: \(error)")
            }

            recentOrders = orders
            self.customers = customers
            customersCount = customers.count
            self.catalog = fetchedCatalog

            let monthPrefix = Self.monthPrefix()
            let monthOrders = orders.filter { ($0.createdAt ?? "").hasPrefix(monthPrefix) }
            todayOrderCount = monthOrders.count
            todaySalesAmount = monthOrders.map(\.totalAmount).reduce(0, +)

            // Seed RatingCache only on first load — after that the cache is
            // maintained locally via incremental averaging on each new submission.
            if !ratingCacheSeeded {
                let values = ratings.compactMap { $0.ratingValue }.map { Double($0) }
                let avg = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
                RatingCache.shared.seed(average: avg, count: values.count)
                ratingCacheSeeded = true
            }

            errorMessage = nil

            // Fetch trending products for dashboard
            await fetchTrendingProducts()

        } catch is CancellationError {
            // SwiftUI cancelled the task — do not surface to user
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchCustomers() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let userId = try await resolveUserId()
            let brandId = try await resolveBrandId(userId: userId)
            let fetched: [Customer] = try await client
                .from("customers")
                .select("*")
                .eq("brand_id", value: brandId)
                .order("created_at", ascending: false)
                .execute()
                .value

            customers = fetched
            customersCount = fetched.count
            errorMessage = nil
        } catch is CancellationError {
            // SwiftUI cancelled the pull-to-refresh task — do not clear data or show error
        } catch {
            // Keep existing customers visible; only update the error banner
            errorMessage = "Failed to load clients: \(error.localizedDescription)"
        }
    }

    func deleteCustomer(customerId: UUID) async {
        do {
            try await client
                .from("customers")
                .delete()
                .eq("id", value: customerId.uuidString)
                .execute()
            
            // Remove from local list
            customers.removeAll { $0.id == customerId }
            customersCount = customers.count
            errorMessage = nil
        } catch {
            errorMessage = "Failed to delete client: \(error.localizedDescription)"
        }
    }

    func fetchCatalog(search: String = "") async {
        do {
            let userId = try await resolveUserId()
            let brandId = try await resolveBrandId(userId: userId)
            var query = client.from("products")
                .select("product_id,name,brand_id,category,price,sku,making_price,image_url,is_active")
                .eq("brand_id", value: brandId)
            
            if !search.isEmpty {
                query = query.ilike("name", value: "%\(search)%")
            }
            let products: [Product] = try await query.limit(50).execute().value
            catalog = products
        } catch {
            print("Failed to fetch catalog search: \(error)")
        }
    }

    // MARK: - Update Order Status (for contextMenu actions in Orders tab)
    func updateOrderStatus(orderId: UUID, status: String) async {
        struct OrderStatusUpdate: Encodable { let status: String }
        struct OrderTrackingInsert: Encodable {
            let order_id: UUID
            let status: String
        }
        
        do {
            try await client
                .from("sales_orders")
                .update(OrderStatusUpdate(status: status))
                .eq("order_id", value: orderId.uuidString)
                .execute()
                
            // Insert into order_tracking table
            try? await client
                .from("order_tracking")
                .insert(OrderTrackingInsert(order_id: orderId, status: status))
                .execute()

            // Update local array in-place
            if let idx = recentOrders.firstIndex(where: { $0.id == orderId }) {
                let current = recentOrders[idx]
                recentOrders[idx] = SAOrder(
                    id: current.id,
                    totalAmount: current.totalAmount,
                    status: status,
                    createdAt: current.createdAt,
                    customerName: current.customerName
                )
            }
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            errorMessage = "Failed to update order status: \(error.localizedDescription)"
        }
    }

    // MARK: - Fetch Trending Products (computed live from order_items)
    func fetchTrendingProducts() async {
        do {
            let userId = try await resolveUserId()
            let brandId = try await resolveBrandId(userId: userId)
            // Postgres returns UUIDs lowercase; Swift's UUID.uuidString is uppercase — normalise both sides
            let brandIdLower = brandId.lowercased()

            // Decode each order_item row joined with its product
            struct OrderItemRow: Decodable {
                let product_id: UUID
                let quantity: Int
                let products: ProductInfo?

                struct ProductInfo: Decodable {
                    let name: String
                    let price: Double
                    let category: String?
                    let brand_id: String?
                }
            }

            // Fetch ALL historical order_items joined with products (no artificial cap)
            let rows: [OrderItemRow] = try await client
                .from("order_items")
                .select("product_id, quantity, products(name, price, category, brand_id)")
                .limit(2000)
                .execute()
                .value

            print("[fetchTrendingProducts] fetched \(rows.count) rows, brand=\(brandIdLower)")

            // Filter to this brand using case-insensitive comparison and aggregate
            var totals: [UUID: (name: String, category: String, price: Double, count: Int)] = [:]
            for row in rows {
                guard let info = row.products,
                      (info.brand_id ?? "").lowercased() == brandIdLower else { continue }
                if let existing = totals[row.product_id] {
                    totals[row.product_id] = (
                        existing.name,
                        existing.category,
                        existing.price,
                        existing.count + row.quantity
                    )
                } else {
                    totals[row.product_id] = (
                        info.name,
                        info.category ?? "",
                        info.price,
                        row.quantity
                    )
                }
            }

            print("[fetchTrendingProducts] \(totals.count) distinct products after brand filter")

            // Sort by total units sold, take top 3
            let sorted = totals
                .sorted { $0.value.count > $1.value.count }
                .prefix(3)

            let maxCount = max(sorted.first?.value.count ?? 1, 1)

            trendingProducts = sorted.map { productId, info in
                // Normalise to 0–100 so flame levels reflect relative velocity
                let score = Double(info.count) / Double(maxCount) * 100.0
                return TrendingProduct(
                    productId: productId,
                    name: info.name,
                    category: info.category,
                    price: info.price,
                    soldCount: info.count,
                    trendScore: score
                )
            }
            print("[fetchTrendingProducts] result: \(trendingProducts.map { "\($0.name): \($0.soldCount)" })")
        } catch is CancellationError {
        } catch {
            print("[fetchTrendingProducts] error: \(error)")
        }
    }


    private static func monthPrefix() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }

    private func resolveCurrentAssociateBrandStoreIds(userId: UUID) async throws -> [String] {
        struct SAStoreRow: Decodable { let store_id: UUID }
        struct StoreBrandRow: Decodable { let brand_id: UUID }
        struct BrandStoreRow: Decodable { let store_id: UUID }

        let saRows: [SAStoreRow] = try await client
            .from("sales_associates")
            .select("store_id")
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        guard let associateStoreId = saRows.first?.store_id else {
            return []
        }

        let storeRows: [StoreBrandRow] = try await client
            .from("stores")
            .select("brand_id")
            .eq("store_id", value: associateStoreId.uuidString)
            .limit(1)
            .execute()
            .value

        guard let brandId = storeRows.first?.brand_id else {
            return [associateStoreId.uuidString]
        }

        let brandStores: [BrandStoreRow] = try await client
            .from("stores")
            .select("store_id")
            .eq("brand_id", value: brandId.uuidString)
            .execute()
            .value

        let ids = brandStores.map { $0.store_id.uuidString }
        return ids.isEmpty ? [associateStoreId.uuidString] : ids
    }

    private func resolveUserId() async throws -> UUID {
        if let session = try? await client.auth.session { return session.user.id }
        return try await client.auth.user().id
    }

    private func resolveBrandId(userId: UUID) async throws -> String {
        print("[resolveBrandId] Resolving for user: \(userId)")

        // 1. Check users table first (like Admin/Inventory)
        struct UserRow: Decodable { let brand_id: UUID? }
        let userRows: [UserRow] = (try? await client
            .from("users")
            .select("brand_id")
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value) ?? []

        if let bId = userRows.first?.brand_id {
            print("[resolveBrandId] Resolved via users table: \(bId)")
            return bId.uuidString
        }

        // 2. Fallback: resolve via store
        print("[resolveBrandId] No brand_id in users, falling back to store resolution")
        struct SAStoreRow: Decodable { let store_id: UUID }
        struct StoreBrandRow: Decodable { let brand_id: UUID }

        let saRows: [SAStoreRow] = try await client
            .from("sales_associates")
            .select("store_id")
            .eq("user_id", value: userId.uuidString)
            .limit(1)
            .execute()
            .value

        guard let storeId = saRows.first?.store_id else {
            throw NSError(domain: "SA", code: 0, userInfo: [NSLocalizedDescriptionKey: "No associate record"])
        }

        let storeRows: [StoreBrandRow] = try await client
            .from("stores")
            .select("brand_id")
            .eq("store_id", value: storeId.uuidString)
            .limit(1)
            .execute()
            .value

        let brandId = storeRows.first?.brand_id.uuidString ?? ""
        print("[resolveBrandId] Resolved via store fallback: \(brandId)")
        return brandId
    }
}
