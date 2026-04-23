import Foundation

// MARK: - Appointment
struct Appointment: Identifiable, Decodable, Sendable {
    let id: UUID
    let customerId: UUID
    let salesAssociateId: UUID
    let storeId: UUID?
    let appointmentAt: String       // ISO8601 timestamptz string from Supabase
    let durationMins: Int
    var status: String              // "scheduled" | "completed" | "cancelled" | "no_show"
    let notes: String?
    let createdAt: String?

    // Joined relations (populated via Supabase select embedding)
    let customer: AppointmentCustomer?
    let appointmentProducts: [AppointmentProductItem]?

    enum CodingKeys: String, CodingKey {
        case id
        case customerId          = "customer_id"
        case salesAssociateId    = "sales_associate_id"
        case storeId             = "store_id"
        case appointmentAt       = "appointment_at"
        case durationMins        = "duration_mins"
        case status
        case notes
        case createdAt           = "created_at"
        case customer            = "customers"
        case appointmentProducts = "appointment_products"
    }

    // MARK: Computed helpers

    /// Parses the ISO8601 timestamptz string into a Swift Date.
    var appointmentDate: Date? {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: appointmentAt) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: appointmentAt)
    }

    /// Human-readable date+time: "Today · 3:30 PM", "Tomorrow · 10:00 AM", "Thu, 24 Apr · 2:00 PM"
    var displayDateTime: String {
        guard let date = appointmentDate else { return appointmentAt }
        let cal = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if cal.isDateInToday(date)    { return "Today · \(time)" }
        if cal.isDateInTomorrow(date) { return "Tomorrow · \(time)" }
        let day = date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        return "\(day) · \(time)"
    }

    /// e.g. "30 min"
    var durationDisplay: String { "\(durationMins) min" }

    /// Status colour name for display
    var statusColor: String {
        switch status {
        case "completed":  return "#4A7C59"
        case "cancelled", "no_show": return "#C0392B"
        default:           return "#C8913A"   // scheduled → amber
        }
    }
}

// MARK: - AppointmentCustomer
// Joined from the `customers` table via Supabase embedding.
struct AppointmentCustomer: Decodable, Sendable {
    let name: String
    let phone: String?
    let customerCategory: String?

    enum CodingKeys: String, CodingKey {
        case name
        case phone
        case customerCategory = "customer_category"
    }
}

// MARK: - AppointmentProductItem
// Joined from the `appointment_products` table.
struct AppointmentProductItem: Identifiable, Decodable, Sendable {
    let id: UUID
    let quantity: Int
    let notes: String?
    let product: AppointmentProductDetail?  // further joined from `products`

    enum CodingKeys: String, CodingKey {
        case id
        case quantity
        case notes
        case product = "products"
    }
}

// MARK: - AppointmentProductDetail
// Joined from the `products` table via appointment_products embedding.
struct AppointmentProductDetail: Decodable, Sendable {
    let productId: UUID
    let name: String
    let price: Double
    let imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case name
        case price
        case imageUrl  = "image_url"
    }
}
