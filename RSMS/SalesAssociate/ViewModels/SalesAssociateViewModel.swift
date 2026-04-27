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

            async let ratingsTask: [SARating] = client
                .from("sales_orders")
                .select("order_id,rating_value")
                .eq("sales_associate_id", value: userId.uuidString)  // ← must be String
                .in("store_id", values: scopedStoreIds)
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

            let todayPrefix = Self.todayPrefix()
            let todays = orders.filter { ($0.createdAt ?? "").hasPrefix(todayPrefix) }
            todayOrderCount = todays.count
            todaySalesAmount = todays.map(\.totalAmount).reduce(0, +)

            // Seed RatingCache only on first load — after that the cache is
            // maintained locally via incremental averaging on each new submission.
            if !ratingCacheSeeded {
                let values = ratings.compactMap { $0.ratingValue }.map { Double($0) }
                let avg = values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
                RatingCache.shared.seed(average: avg, count: values.count)
                ratingCacheSeeded = true
            }

            errorMessage = nil
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

    func completeOrder(orderId: UUID) async {
        struct OrderStatusUpdate: Encodable { let status: String }

        do {
            try await client
                .from("sales_orders")
                .update(OrderStatusUpdate(status: "completed"))
                .eq("order_id", value: orderId.uuidString)
                .execute()

            if let index = recentOrders.firstIndex(where: { $0.id == orderId }) {
                let current = recentOrders[index]
                recentOrders[index] = SAOrder(
                    id: current.id,
                    totalAmount: current.totalAmount,
                    status: "completed",
                    createdAt: current.createdAt,
                    customerName: current.customerName
                )
            }

            errorMessage = nil
        } catch is CancellationError {
            // Task cancelled by UI lifecycle; do nothing.
        } catch {
            errorMessage = "Failed to complete order: \(error.localizedDescription)"
        }
    }

    private static func todayPrefix() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
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
