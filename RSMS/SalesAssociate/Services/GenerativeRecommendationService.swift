import Foundation
import Supabase

public class GenerativeRecommendationService {
    public static let shared = GenerativeRecommendationService()

    public struct RecommendationResult {
        public let products: [Product]
        public let diagnosticMessage: String?
    }
    
    private init() {}
    
    /// Fetches 3 AI-recommended products based on the current cart contents
    public func getRecommendations(cartItems: [Product], availableCatalog: [Product]) async -> [Product] {
        let result = await getRecommendationsResult(cartItems: cartItems, availableCatalog: availableCatalog)
        return result.products
    }

    public func getRecommendationsResult(cartItems: [Product], availableCatalog: [Product]) async -> RecommendationResult {
        guard !availableCatalog.isEmpty else {
            return RecommendationResult(
                products: [],
                diagnosticMessage: "No active catalog items are available for recommendations."
            )
        }

        // 1. Format the data for the AI
        let cartDescriptions = cartItems.map { "\($0.name) (\($0.category))" }.joined(separator: ", ")
        
        // Exclude items already in the cart from the catalog options
        let cartIds = Set(cartItems.map { $0.id })
        var catalogMap: [String: String] = [:]
        
        for product in availableCatalog where !cartIds.contains(product.id) {
            catalogMap[product.id.uuidString] = product.name
        }

        guard !catalogMap.isEmpty else {
            return RecommendationResult(
                products: [],
                diagnosticMessage: "All visible catalog items are already selected."
            )
        }
        
        // 2. Setup the payload for the Edge Function
        struct Payload: Encodable {
            let cartDescriptions: String
            let catalogMap: [String: String]
        }
        let payload = Payload(cartDescriptions: cartDescriptions, catalogMap: catalogMap)
        
        do {
            // 3. Call the Supabase Edge Function
            let response: [String] = try await SupabaseManager.shared.client.functions
                .invoke("recommend-products", options: .init(body: payload))

            guard !response.isEmpty else {
                return RecommendationResult(
                    products: [],
                    diagnosticMessage: "AI returned no suggestions for this client context."
                )
            }

            let responseSet = Set(response.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            
            // 4. Map the returned string IDs back to your real Product models
            let recommendedProducts = availableCatalog.filter {
                responseSet.contains($0.id.uuidString.lowercased())
            }

            if recommendedProducts.isEmpty {
                return RecommendationResult(
                    products: [],
                    diagnosticMessage: "AI suggestions did not match current catalog items."
                )
            }

            return RecommendationResult(products: recommendedProducts, diagnosticMessage: nil)
            
        } catch {
            print("❌ Generative AI Recommendation failed: \(error.localizedDescription)")
            return RecommendationResult(
                products: [],
                diagnosticMessage: "AI service is temporarily unavailable (\(error.localizedDescription))."
            )
        }
    }
}
