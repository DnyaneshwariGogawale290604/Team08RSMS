import Foundation
import Combine
import Supabase
import PostgREST

@MainActor
final class AppointmentsViewModel: ObservableObject {
    @Published var appointments: [Appointment] = []
    @Published var customers: [Customer] = []
    @Published var catalog: [Product] = []
    @Published var isLoading = false
    @Published var isCreating = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    private let client = SupabaseManager.shared.client

    // MARK: - Fetch appointments (scheduled only, ordered by time)
    func fetchAppointments() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let userId = try await resolveUserId()
            let result: [Appointment] = try await client
                .from("appointments")
                .select("""
                    id, customer_id, sales_associate_id, store_id,
                    appointment_at, duration_mins, status, notes, created_at,
                    customers(name, phone, customer_category),
                    appointment_products(
                        id, quantity, notes,
                        products(product_id, name, price, image_url)
                    )
                """)
                .eq("sales_associate_id", value: userId.uuidString)
                .in("status", values: ["scheduled", "completed"])
                .order("appointment_at", ascending: true)
                .execute()
                .value
            appointments = result
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Fetch customers + catalog (for new appointment form)
    func fetchCustomersAndCatalog() async {
        do {
            async let cTask: [Customer] = client
                .from("customers")
                .select("*")
                .order("name", ascending: true)
                .limit(100)
                .execute()
                .value
            async let pTask: [Product] = client
                .from("products")
                .select("product_id, name, brand_id, category, price, sku, making_price, image_url, is_active")
                .eq("is_active", value: true)
                .limit(100)
                .execute()
                .value
            customers = try await cTask
            catalog   = try await pTask
        } catch {
            print("[AppointmentsVM] fetchCustomersAndCatalog failed: \(error)")
        }
    }

    // MARK: - Create appointment
    func createAppointment(
        customerId: UUID,
        at date: Date,
        durationMins: Int,
        notes: String?,
        products: [(productId: UUID, quantity: Int, notes: String?)]
    ) async {
        isCreating = true
        defer { isCreating = false }
        do {
            let userId = try await resolveUserId()

            // Resolve store_id from sales_associates
            struct SAStore: Decodable { let store_id: UUID }
            let saRows: [SAStore] = try await client
                .from("sales_associates")
                .select("store_id")
                .eq("user_id", value: userId.uuidString)
                .limit(1)
                .execute()
                .value
            let storeId = saRows.first?.store_id

            // Insert appointment row
            struct ApptInsert: Encodable {
                let customer_id: UUID
                let sales_associate_id: UUID
                let store_id: UUID?
                let appointment_at: String
                let duration_mins: Int
                let notes: String?
            }
            struct ApptRow: Decodable { let id: UUID }

            let isoDate = ISO8601DateFormatter().string(from: date)
            let row: ApptRow = try await client
                .from("appointments")
                .insert(ApptInsert(
                    customer_id: customerId,
                    sales_associate_id: userId,
                    store_id: storeId,
                    appointment_at: isoDate,
                    duration_mins: durationMins,
                    notes: notes?.isEmpty == true ? nil : notes
                ))
                .select("id")
                .single()
                .execute()
                .value

            // Insert appointment_products
            if !products.isEmpty {
                struct APInsert: Encodable {
                    let appointment_id: UUID
                    let product_id: UUID
                    let quantity: Int
                    let notes: String?
                }
                let items = products.map {
                    APInsert(appointment_id: row.id,
                             product_id: $0.productId,
                             quantity: $0.quantity,
                             notes: $0.notes?.isEmpty == true ? nil : $0.notes)
                }
                try await client.from("appointment_products").insert(items).execute()
            }

            successMessage = "Appointment booked!"
            await fetchAppointments()
        } catch {
            errorMessage = "Failed to create appointment: \(error.localizedDescription)"
        }
    }

    // MARK: - Update status (complete / cancel / no_show)
    func updateStatus(_ status: String, for appointmentId: UUID) async {
        do {
            struct StatusUpdate: Encodable { let status: String }
            try await client
                .from("appointments")
                .update(StatusUpdate(status: status))
                .eq("id", value: appointmentId.uuidString)
                .execute()
            
            // If it's cancelled or no-show, remove from the local "active" list.
            // If it's completed, we now keep it (since fetchAppointments includes completed).
            if status != "completed" {
                appointments.removeAll { $0.id == appointmentId }
            } else {
                // Update the status locally so the UI can reflect it if needed
                if let idx = appointments.firstIndex(where: { $0.id == appointmentId }) {
                    appointments[idx].status = status
                }
            }
        } catch {
            errorMessage = "Failed to update appointment."
        }
    }

    // MARK: - Delete appointment
    func deleteAppointment(id: UUID) async {
        do {
            // 1. Delete associated products first (to handle FK constraints)
            try await client
                .from("appointment_products")
                .delete()
                .eq("appointment_id", value: id.uuidString)
                .execute()

            // 2. Delete the appointment itself
            try await client
                .from("appointments")
                .delete()
                .eq("id", value: id.uuidString)
                .execute()
            
            // 3. Remove from local state
            appointments.removeAll { $0.id == id }
        } catch {
            print("[deleteAppointment] Error: \(error)")
            errorMessage = "Failed to delete appointment."
        }
    }

    // MARK: - Fetch full Customer by ID (for cart pre-fill)
    func fetchCustomer(id: UUID) async throws -> Customer {
        let rows: [Customer] = try await client
            .from("customers")
            .select("*")
            .eq("customer_id", value: id.uuidString)
            .limit(1)
            .execute()
            .value
        guard let customer = rows.first else {
            throw NSError(domain: "AppointmentsVM", code: 404,
                          userInfo: [NSLocalizedDescriptionKey: "Customer not found"])
        }
        return customer
    }

    // MARK: - Fetch Products by IDs (for cart pre-fill)
    func fetchProducts(ids: [UUID]) async throws -> [Product] {
        guard !ids.isEmpty else { return [] }
        let idStrings = ids.map { $0.uuidString }
        let rows: [Product] = try await client
            .from("products")
            .select("product_id, name, brand_id, category, price, sku, making_price, image_url, is_active")
            .in("product_id", values: idStrings)
            .execute()
            .value
        return rows
    }

    // MARK: - Auth helper
    func resolveUserId() async throws -> UUID {
        let auth = client.auth
        if let session = try? await auth.session { return session.user.id }
        return try await auth.user().id
    }
}
