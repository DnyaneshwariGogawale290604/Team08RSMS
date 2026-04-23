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
            let userId = try await client.auth.session.user.id

            async let ordersTask: [SAOrder] = client
                .from("sales_orders")
                .select("order_id,total_amount,status,created_at,customers(name)")
                .eq("sales_associate_id", value: userId)
                .order("created_at", ascending: false)
                .limit(20)
                .execute()
                .value

            async let ratingsTask: [SARating] = client
                .from("sales_orders")
                .select("order_id,rating_value")
                .eq("sales_associate_id", value: userId)
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
                .limit(50)
                .execute()
                .value



            let orders = try await ordersTask
            let ratings = try await ratingsTask
            let customers = try await customersTask

            var fetchedCatalog: [Product] = []
            do {
                fetchedCatalog = try await catalogTask
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
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func fetchCatalog(search: String = "") async {
        do {
            var query = client.from("products").select("product_id,name,brand_id,category,price,sku,making_price,image_url,is_active")
            if !search.isEmpty {
                query = query.ilike("name", value: "%\(search)%")
            }
            let products: [Product] = try await query.limit(50).execute().value
            catalog = products
        } catch {
            print("Failed to fetch catalog search: \(error)")
        }
    }

    private static func todayPrefix() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: Date())
    }
}
