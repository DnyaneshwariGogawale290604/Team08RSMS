import Foundation
import Supabase

public class GenerativeRecommendationService {
    public static let shared = GenerativeRecommendationService()
    
    private init() {}
    
    /// Fetches 3 AI-recommended products based on the current cart contents
    public func getRecommendations(cartItems: [Product], availableCatalog: [Product]) async -> [Product] {
        // 1. Format the data for the AI
        let cartDescriptions = cartItems.map { "\($0.name) (\($0.category))" }.joined(separator: ", ")
        
        // Exclude items already in the cart from the catalog options
        let cartIds = Set(cartItems.map { $0.id })
        var catalogMap: [String: String] = [:]
        
        for product in availableCatalog where !cartIds.contains(product.id) {
            catalogMap[product.id.uuidString] = product.name
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
            
            // 4. Map the returned string IDs back to your real Product models
            let recommendedProducts = availableCatalog.filter { response.contains($0.id.uuidString) }
            return recommendedProducts
            
        } catch {
            print("❌ Generative AI Recommendation failed: \(error.localizedDescription)")
            return []
        }
    }
}
