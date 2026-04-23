import Foundation
import Supabase
import PostgREST

public final class RoleService: @unchecked Sendable {
    public static let shared = RoleService()

    private let client = SupabaseManager.shared.client

    private init() {}

    public func resolveRole(for userId: UUID) async throws -> AppRole? {
        async let isCorporateAdmin = exists(
            table: "corporate_admins",
            idColumn: "user_id",
            userId: userId
        )

        async let isInventoryManager = exists(
            table: "inventory_managers",
            idColumn: "user_id",
            userId: userId
        )

        async let isBoutiqueManager = exists(
            table: "boutique_managers",
            idColumn: "user_id",
            userId: userId
        )

        async let isSalesAssociate = exists(
            table: "sales_associates",
            idColumn: "user_id",
            userId: userId
        )

        if try await isCorporateAdmin {
            return .corporateAdmin
        }

        if try await isInventoryManager {
            return .inventoryManager
        }

        if try await isBoutiqueManager {
            return .boutiqueManager
        }

        if try await isSalesAssociate {
            return .salesAssociate
        }

        return nil
    }

    private func exists(table: String, idColumn: String, userId: UUID) async throws -> Bool {
        struct RoleRow: Decodable {
            let userId: UUID

            enum CodingKeys: String, CodingKey {
                case userId = "user_id"
            }
        }

        let rows: [RoleRow] = try await client
            .from(table)
            .select(idColumn)
            .eq(idColumn, value: userId)
            .limit(1)
            .execute()
            .value

        return !rows.isEmpty
    }
}
