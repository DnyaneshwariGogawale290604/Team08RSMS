import Foundation
import Supabase
import PostgREST
import UIKit

public final class ProductService: @unchecked Sendable {
    nonisolated(unsafe) public static let shared = ProductService()
    nonisolated(unsafe) private let client = SupabaseManager.shared.client
    private let productImageBucket = "products"

    private init() {}

    public func fetchProducts() async throws -> [Product] {
        let brandId = try await resolveCurrentUserBrandIdOrThrow()

        let response: PostgrestResponse<[Product]> = try await client
            .from("products")
            .select("product_id,name,brand_id,category,price,sku,making_price,image_url,is_active,tax,total_price")
            .eq("brand_id", value: brandId)
            .order("name", ascending: true)
            .execute()

        return response.value
    }

    public func uploadImage(_ image: UIImage) async -> String? {
        print("UPLOADING IMAGE...")

        guard let imageData = image.jpegData(compressionQuality: 0.85) else {
            print("Image upload failed:", ProductImageUploadError.jpegEncodingFailed)
            print("IMAGE URL:", "nil")
            return nil
        }

        let path = UUID().uuidString + ".jpg"

        do {
            try await client.storage
                .from(productImageBucket)
                .upload(
                    path,
                    data: imageData,
                    options: FileOptions(
                        cacheControl: "3600",
                        contentType: "image/jpeg",
                        upsert: false
                    )
                )
        } catch {
            print("Image upload threw an error, but it might be benign (e.g. JSON decode error on success):", error)
        }

        do {
            let publicURLData = try client.storage
                .from(productImageBucket)
                .getPublicURL(path: path)
            let imageUrl = publicURLData.absoluteString

            print("IMAGE URL:", imageUrl)
            return imageUrl
        } catch {
            print("Image upload failed to get public URL:", error)
            print("IMAGE URL:", "nil")
            return nil
        }
    }

    public func addProduct(_ product: Product, image: UIImage?) async throws -> Product {
        let imageUrl: String?
        if let image {
            imageUrl = await uploadImage(image)
        } else {
            imageUrl = nil
        }

        struct ProductInsert: Encodable {
            let product_id: UUID
            let name: String?
            let brand_id: UUID?
            let category: String?
            let price: Double?
            let sku: String?
            let making_price: Double?
            let image_url: String?
            let is_active: Bool
        }

        let brandId = await resolveBrandId(product.brandId)
        print("INSERT PRODUCT:", product)
        print("INSERT PRODUCT PAYLOAD COLUMNS: product_id,name,brand_id,category,price,sku,making_price,image_url,is_active")

        do {
            let payload = ProductInsert(
                product_id: product.id,
                name: product.name,
                brand_id: brandId,
                category: product.category,
                price: product.price,
                sku: product.sku,
                making_price: product.makingPrice,
                image_url: imageUrl,
                is_active: product.isActive ?? true
            )
            print("Insert payload:", payload)

            let response: PostgrestResponse<Product> = try await client
                .from("products")
                .insert(payload)
                .select("product_id,name,brand_id,category,price,sku,making_price,image_url,is_active,tax,total_price")
                .single()
                .execute()

            print("Insert response:", response)
            print("INSERT SUCCESS")
            return response.value
        } catch {
            print("INSERT ERROR:", error)
            throw error
        }
    }

    private func resolveBrandId(_ brandId: UUID?) async -> UUID? {
        if let brandId {
            print("PRODUCT BRAND ID FROM FORM:", brandId)
            return brandId
        }

        struct UserBrand: Decodable {
            let brand_id: UUID?
        }

        do {
            let userId = try await client.auth.session.user.id
            print("RESOLVE BRAND: current auth user:", userId)

            let response: PostgrestResponse<[UserBrand]> = try await client
                .from("users")
                .select("brand_id")
                .eq("user_id", value: userId)
                .execute()

            print("RESOLVE BRAND RESPONSE STATUS:", response.status)
            print("RESOLVE BRAND RAW:", response.string() ?? "nil")

            let resolvedBrandId = response.value.first?.brand_id
            print("RESOLVE BRAND ID:", resolvedBrandId as Any)
            return resolvedBrandId
        } catch {
            print("RESOLVE BRAND ERROR:", error)
            return nil
        }
    }

    public func updateProduct(_ product: Product) async throws {
        let currentBrandId = try await resolveCurrentUserBrandIdOrThrow()
        let productBrandId = try await fetchProductBrandId(productId: product.id)
        guard productBrandId == currentBrandId else {
            throw ProductServiceError.productOutsideCurrentBrand
        }

        struct ProductUpdate: Encodable {
            let name: String
            let category: String
            let price: Double
            let sku: String?
            let making_price: Double?
            let is_active: Bool
        }

        let updatePayload = ProductUpdate(
            name: product.name,
            category: product.category,
            price: product.price,
            sku: product.sku,
            making_price: product.makingPrice,
            is_active: product.isActive ?? true
        )

        try await client
            .from("products")
            .update(updatePayload)
            .eq("product_id", value: product.id)
            .execute()
    }

    public func archiveProduct(id: UUID) async throws {
        try await toggleProductActiveStatus(productId: id, isActive: false)
    }

    public func toggleProductActiveStatus(productId: UUID, isActive: Bool) async throws {
        let currentBrandId = try await resolveCurrentUserBrandIdOrThrow()
        let productBrandId = try await fetchProductBrandId(productId: productId)
        guard productBrandId == currentBrandId else {
            throw ProductServiceError.productOutsideCurrentBrand
        }

        struct ActiveUpdate: Encodable {
            let is_active: Bool
        }
        try await client
            .from("products")
            .update(ActiveUpdate(is_active: isActive))
            .eq("product_id", value: productId)
            .execute()
    }

    private func fetchProductBrandId(productId: UUID) async throws -> UUID? {
        struct ProductBrandRow: Decodable {
            let brandId: UUID?

            enum CodingKeys: String, CodingKey {
                case brandId = "brand_id"
            }
        }

        let rows: [ProductBrandRow] = try await client
            .from("products")
            .select("brand_id")
            .eq("product_id", value: productId)
            .limit(1)
            .execute()
            .value

        return rows.first?.brandId
    }

    private func resolveCurrentUserBrandIdOrThrow() async throws -> UUID {
        struct UserBrand: Decodable {
            let brandId: UUID?

            enum CodingKeys: String, CodingKey {
                case brandId = "brand_id"
            }
        }

        let userId = try await client.auth.session.user.id

        let response: PostgrestResponse<[UserBrand]> = try await client
            .from("users")
            .select("brand_id")
            .eq("user_id", value: userId)
            .limit(1)
            .execute()

        guard let brandId = response.value.first?.brandId else {
            throw ProductServiceError.missingCurrentUserBrand
        }

        return brandId
    }
}

private enum ProductServiceError: LocalizedError {
    case missingCurrentUserBrand
    case productOutsideCurrentBrand

    var errorDescription: String? {
        switch self {
        case .missingCurrentUserBrand:
            return "Current user is not linked to a brand."
        case .productOutsideCurrentBrand:
            return "This product belongs to a different brand."
        }
    }
}

private enum ProductImageUploadError: LocalizedError {
    case jpegEncodingFailed

    var errorDescription: String? {
        switch self {
        case .jpegEncodingFailed:
            return "Unable to prepare product image for upload."
        }
    }
}
