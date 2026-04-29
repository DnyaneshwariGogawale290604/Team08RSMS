import Foundation

public struct Product: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var brandId: UUID?
    public var category: String
    public var price: Double
    public var sku: String?
    public var makingPrice: Double?
    public var imageUrl: String?
    public var isActive: Bool?
    public var tax: Double?
    public var totalPrice: Double?
    public var sizeOptions: [String]?
    public var reorderPoint: Int?
    public var reorderQuantity: Int?
    public var stockQuantity: Int?
    public var variants: [ProductVariant]?
    public var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "product_id"
        case name
        case brandId = "brand_id"
        case category
        case price
        case sku
        case makingPrice = "making_price"
        case imageUrl = "image_url"
        case isActive = "is_active"
        case tax
        case totalPrice = "total_price"
        case sizeOptions = "size_options"
        case createdAt = "created_at"
    }

    // Custom decoder: DB columns are all nullable (text, numeric) so we
    // provide safe fallbacks to avoid a hard decode failure when any field is NULL.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id         = try c.decode(UUID.self, forKey: .id)
        name       = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "Unnamed Product"
        brandId    = try? c.decodeIfPresent(UUID.self, forKey: .brandId) ?? nil
        category   = (try? c.decodeIfPresent(String.self, forKey: .category)) ?? ""
        // Supabase returns numeric as either Double or String; try both
        if let d = try? c.decodeIfPresent(Double.self, forKey: .price) {
            price = d
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .price), let d = Double(s) {
            price = d
        } else {
            price = 0
        }
        sku        = try? c.decodeIfPresent(String.self, forKey: .sku) ?? nil
        if let mp = try? c.decodeIfPresent(Double.self, forKey: .makingPrice) {
            makingPrice = mp
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .makingPrice), let d = Double(s) {
            makingPrice = d
        } else {
            makingPrice = nil
        }
        imageUrl   = try? c.decodeIfPresent(String.self, forKey: .imageUrl) ?? nil
        isActive   = try? c.decodeIfPresent(Bool.self, forKey: .isActive) ?? nil
        if let t = try? c.decodeIfPresent(Double.self, forKey: .tax) {
            tax = t
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .tax), let d = Double(s) {
            tax = d
        } else {
            tax = nil
        }
        if let tp = try? c.decodeIfPresent(Double.self, forKey: .totalPrice) {
            totalPrice = tp
        } else if let s = try? c.decodeIfPresent(String.self, forKey: .totalPrice), let d = Double(s) {
            totalPrice = d
        } else {
            totalPrice = nil
        }
        // size_options is a jsonb array of strings
        if let arr = try? c.decodeIfPresent([String].self, forKey: .sizeOptions) {
            sizeOptions = arr.isEmpty ? nil : arr
        } else {
            sizeOptions = nil
        }
        reorderPoint = 5
        reorderQuantity = 20
        stockQuantity = nil
        variants = nil
        
        if let date = try? c.decodeIfPresent(Date.self, forKey: .createdAt) {
            createdAt = date
        } else {
            createdAt = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(brandId, forKey: .brandId)
        try c.encode(category, forKey: .category)
        try c.encode(price, forKey: .price)
        try c.encodeIfPresent(sku, forKey: .sku)
        try c.encodeIfPresent(makingPrice, forKey: .makingPrice)
        try c.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try c.encodeIfPresent(isActive, forKey: .isActive)
        try c.encodeIfPresent(tax, forKey: .tax)
        try c.encodeIfPresent(totalPrice, forKey: .totalPrice)
        try c.encodeIfPresent(sizeOptions, forKey: .sizeOptions)
        try c.encodeIfPresent(createdAt, forKey: .createdAt)
    }

    // Memberwise init for constructing products in code
    public init(id: UUID = UUID(), name: String, brandId: UUID? = nil, category: String,
                price: Double, sku: String? = nil, makingPrice: Double? = nil,
                imageUrl: String? = nil, isActive: Bool? = true,
                tax: Double? = nil, totalPrice: Double? = nil, sizeOptions: [String]? = nil,
                reorderPoint: Int? = 5, reorderQuantity: Int? = 20, stockQuantity: Int? = nil,
                variants: [ProductVariant]? = nil, createdAt: Date? = nil) {
        self.id = id
        self.name = name
        self.brandId = brandId
        self.category = category
        self.price = price
        self.sku = sku
        self.makingPrice = makingPrice
        self.imageUrl = imageUrl
        self.isActive = isActive
        self.tax = tax
        self.totalPrice = totalPrice
        self.sizeOptions = sizeOptions
        self.reorderPoint = reorderPoint
        self.reorderQuantity = reorderQuantity
        self.stockQuantity = stockQuantity
        self.variants = variants
        self.createdAt = createdAt
    }

    public enum StockStatus: Int, Comparable {
        case urgent = 0
        case low = 1
        case normal = 2
        
        public static func < (lhs: StockStatus, rhs: StockStatus) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    public var stockStatus: StockStatus {
        let stock = stockQuantity ?? 0
        let reorder = reorderPoint ?? 5
        if stock <= reorder / 2 {
            return .urgent
        } else if stock <= reorder {
            return .low
        } else {
            return .normal
        }
    }

    public var displayImageUrl: String? {
        allImageUrls.first
    }

    public var allImageUrls: [String] {
        let variantUrls = displayVariants
            .flatMap(\.imageUrls)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let productUrl = imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        if !variantUrls.isEmpty {
            return variantUrls
        }

        if let productUrl, !productUrl.isEmpty {
            return [productUrl]
        }

        return []
    }

    public var displayVariants: [ProductVariant] {
        if let variants, !variants.isEmpty {
            return variants
        }

        let fallbackUrl = imageUrl?.trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            ProductVariant(
                id: id,
                productId: id,
                name: "Base Model",
                imageUrls: fallbackUrl?.isEmpty == false ? [fallbackUrl!] : []
            )
        ]
    }
}

public struct ProductVariant: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var productId: UUID
    public var name: String
    public var imageUrls: [String]
    public var infoText: String?
    public var createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id = "variant_id"
        case productId = "product_id"
        case name
        case imageUrls = "image_urls"
        case infoText = "info_text"
        case createdAt = "created_at"
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        productId = try c.decode(UUID.self, forKey: .productId)
        name = (try? c.decodeIfPresent(String.self, forKey: .name)) ?? "Unnamed Variant"
        imageUrls = (try? c.decodeIfPresent([String].self, forKey: .imageUrls)) ?? []
        infoText = try? c.decodeIfPresent(String.self, forKey: .infoText) ?? nil

        if let date = try? c.decodeIfPresent(Date.self, forKey: .createdAt) {
            createdAt = date
        } else {
            createdAt = nil
        }
    }

    public init(
        id: UUID = UUID(),
        productId: UUID,
        name: String,
        imageUrls: [String] = [],
        infoText: String? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.productId = productId
        self.name = name
        self.imageUrls = imageUrls
        self.infoText = infoText
        self.createdAt = createdAt
    }
}
