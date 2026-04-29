import Foundation
import Supabase

public final class DiscountService: @unchecked Sendable {
    public static let shared = DiscountService()
    private let client = SupabaseManager.shared.client
    
    private init() {}
    
    public func fetchCoupons() async throws -> [DiscountCoupon] {
        let brandId = try await fetchCurrentCorporateAdminBrandId()
        return try await client
            .from("discount_coupons")
            .select()
            .eq("brand_id", value: brandId)
            .order("created_at", ascending: false)
            .execute()
            .value
    }
    
    public func fetchCoupon(id: UUID) async throws -> DiscountCoupon {
        try await client
            .from("discount_coupons")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }
    
    public func createCoupon(_ coupon: DiscountCoupon, storeIds: [UUID]) async throws {
        let brandId = try await fetchCurrentCorporateAdminBrandId()
        let userId = try await client.auth.session.user.id
        
        // 1. Insert Coupon
        let insertedCoupon: DiscountCoupon = try await client
            .from("discount_coupons")
            .insert(DiscountCouponInsert(coupon: coupon, brandId: brandId, createdBy: userId))
            .select()
            .single()
            .execute()
            .value
        
        // 2. Insert Visibility
        if !storeIds.isEmpty {
            let visibilityRows = storeIds.map { ["coupon_id": insertedCoupon.id.uuidString, "store_id": $0.uuidString] }
            try await client
                .from("discount_store_visibility")
                .insert(visibilityRows)
                .execute()
        }
    }
    
    public func updateCoupon(_ coupon: DiscountCoupon, storeIds: [UUID]) async throws {
        // 1. Update Coupon
        try await client
            .from("discount_coupons")
            .update(DiscountCouponUpdate(coupon: coupon))
            .eq("id", value: coupon.id)
            .execute()
        
        // 2. Update Visibility (Delete then Insert)
        try await client
            .from("discount_store_visibility")
            .delete()
            .eq("coupon_id", value: coupon.id)
            .execute()
        
        if !storeIds.isEmpty {
            let visibilityRows = storeIds.map { ["coupon_id": coupon.id.uuidString, "store_id": $0.uuidString] }
            try await client
                .from("discount_store_visibility")
                .insert(visibilityRows)
                .execute()
        }
    }
    
    public func updateCouponStatus(id: UUID, isActive: Bool) async throws {
        try await client
            .from("discount_coupons")
            .update(["is_active": isActive])
            .eq("id", value: id)
            .execute()
    }
    
    public func deleteCoupon(id: UUID, softDelete: Bool = false) async throws {
        if softDelete {
            try await client
                .from("discount_coupons")
                .update(SoftDeleteUpdate(is_active: false, valid_until: ISO8601DateFormatter().string(from: Date())))
                .eq("id", value: id)
                .execute()
        } else {
            try await client
                .from("discount_coupons")
                .delete()
                .eq("id", value: id)
                .execute()
        }
    }
    
    public func fetchCouponStores(couponId: UUID) async throws -> [UUID] {
        struct VisibilityRow: Decodable { let store_id: UUID }
        let rows: [VisibilityRow] = try await client
            .from("discount_store_visibility")
            .select("store_id")
            .eq("coupon_id", value: couponId)
            .execute()
            .value
        return rows.map(\.store_id)
    }
    
    public func fetchCouponUsages(couponId: UUID, limit: Int = 20, offset: Int = 0) async throws -> [DiscountUsage] {
        return try await client
            .from("discount_usages")
            .select("*, stores(name), users:applied_by(name)")
            .eq("coupon_id", value: couponId)
            .range(from: offset, to: offset + limit - 1)
            .order("applied_at", ascending: false)
            .execute()
            .value
    }
    
    public func fetchUsageStats() async throws -> (total: Int, active: Int, expired: Int, totalDiscount: Double) {
        let brandId = try await fetchCurrentCorporateAdminBrandId()
        let coupons: [DiscountCoupon] = try await fetchCoupons()
        
        let total = coupons.count
        let active = coupons.filter { $0.isActive && ($0.validUntil == nil || $0.validUntil! > Date()) }.count
        let expired = coupons.filter { $0.validUntil != nil && $0.validUntil! <= Date() }.count
        
        // Sum of all discount_amount from discount_usages for this brand by joining with coupons
        let usages: [DiscountUsage] = (try? await client
            .from("discount_usages")
            .select("discount_amount, discount_coupons!inner(brand_id)")
            .eq("discount_coupons.brand_id", value: brandId)
            .execute()
            .value) ?? []
        
        let totalDiscount = usages.reduce(0) { $0 + $1.discountAmount }
        
        return (total, active, expired, totalDiscount)
    }
    
    public func isCodeUnique(_ code: String, brandId: UUID) async throws -> Bool {
        let rows: [DiscountCoupon] = try await client
            .from("discount_coupons")
            .select("id")
            .eq("brand_id", value: brandId)
            .eq("code", value: code.uppercased())
            .execute()
            .value
        return rows.isEmpty
    }

    private func fetchCurrentCorporateAdminBrandId() async throws -> UUID {
        let currentUserId = try await client.auth.session.user.id
        struct BrandRow: Decodable { let brand_id: UUID }
        let rows: [BrandRow] = try await client
            .from("users")
            .select("brand_id")
            .eq("user_id", value: currentUserId)
            .limit(1)
            .execute()
            .value
        guard let brandId = rows.first?.brand_id else {
            throw NSError(domain: "DiscountService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Brand context missing"])
        }
        return brandId
    }
}

// Helper structs for insert/update
private struct DiscountCouponInsert: Encodable {
    let id: UUID
    let brand_id: UUID
    let created_by: UUID
    let code: String
    let description: String?
    let discount_type: String
    let discount_value: Double
    let min_order_amount: Double
    let max_discount_cap: Double?
    let valid_from: String
    let valid_until: String?
    let usage_limit: Int?
    let is_active: Bool

    init(coupon: DiscountCoupon, brandId: UUID, createdBy: UUID) {
        let formatter = ISO8601DateFormatter()
        self.id = coupon.id
        self.brand_id = brandId
        self.created_by = createdBy
        self.code = coupon.code.uppercased()
        self.description = coupon.description
        self.discount_type = coupon.discountType.rawValue
        self.discount_value = coupon.discountValue
        self.min_order_amount = coupon.minOrderAmount
        self.max_discount_cap = coupon.maxDiscountCap
        self.valid_from = formatter.string(from: coupon.validFrom)
        self.valid_until = coupon.validUntil.map { formatter.string(from: $0) }
        self.usage_limit = coupon.usageLimit
        self.is_active = coupon.isActive
    }
}

private struct DiscountCouponUpdate: Encodable {
    let code: String
    let description: String?
    let discount_type: String
    let discount_value: Double
    let min_order_amount: Double
    let max_discount_cap: Double?
    let valid_from: String
    let valid_until: String?
    let usage_limit: Int?
    let is_active: Bool

    init(coupon: DiscountCoupon) {
        let formatter = ISO8601DateFormatter()
        self.code = coupon.code.uppercased()
        self.description = coupon.description
        self.discount_type = coupon.discountType.rawValue
        self.discount_value = coupon.discountValue
        self.min_order_amount = coupon.minOrderAmount
        self.max_discount_cap = coupon.maxDiscountCap
        self.valid_from = formatter.string(from: coupon.validFrom)
        self.valid_until = coupon.validUntil.map { formatter.string(from: $0) }
        self.usage_limit = coupon.usageLimit
        self.is_active = coupon.isActive
    }
}
private struct SoftDeleteUpdate: Encodable {
    let is_active: Bool
    let valid_until: String
}

