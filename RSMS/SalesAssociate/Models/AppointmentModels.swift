import Foundation

// MARK: - Appointment
public struct Appointment: Identifiable, Decodable, Sendable {
    public let id: UUID
    public let customerId: UUID
    public let salesAssociateId: UUID
    public let storeId: UUID?
    public let appointmentAt: String       // ISO8601 timestamptz string from Supabase
    public let durationMins: Int
    public var status: String              // "scheduled" | "completed" | "cancelled" | "no_show"
    public let notes: String?
    public let createdAt: String?

    // Joined relations (populated via Supabase select embedding)
    public let customer: AppointmentCustomer?
    public let appointmentProducts: [AppointmentProductItem]?

    public enum CodingKeys: String, CodingKey {
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
    public var appointmentDate: Date? {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = fmt.date(from: appointmentAt) { return d }
        fmt.formatOptions = [.withInternetDateTime]
        return fmt.date(from: appointmentAt)
    }

    /// Human-readable date+time: "Today · 3:30 PM", "Tomorrow · 10:00 AM", "Thu, 24 Apr · 2:00 PM"
    public var displayDateTime: String {
        guard let date = appointmentDate else { return appointmentAt }
        let cal = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if cal.isDateInToday(date)    { return "Today · \(time)" }
        if cal.isDateInTomorrow(date) { return "Tomorrow · \(time)" }
        let day = date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        return "\(day) · \(time)"
    }

    /// e.g. "30 min"
    public var durationDisplay: String { "\(durationMins) min" }

    /// Status colour name for display
    public var statusColor: String {
        switch status {
        case "completed":  return "#4A7C59"
        case "cancelled", "no_show": return "#C0392B"
        default:           return "#C8913A"   // scheduled → amber
        }
    }
}

// MARK: - AppointmentCustomer
// Joined from the `customers` table via Supabase embedding.
public struct AppointmentCustomer: Decodable, Sendable {
    public let name: String
    public let phone: String?
    public let customerCategory: String?

    public enum CodingKeys: String, CodingKey {
        case name
        case phone
        case customerCategory = "customer_category"
    }
}

// MARK: - AppointmentProductItem
// Joined from the `appointment_products` table.
public struct AppointmentProductItem: Identifiable, Decodable, Sendable {
    public let id: UUID
    public let quantity: Int
    public let notes: String?
    public let product: AppointmentProductDetail?  // further joined from `products`

    public enum CodingKeys: String, CodingKey {
        case id
        case quantity
        case notes
        case product = "products"
    }
}

// MARK: - AppointmentProductDetail
// Joined from the `products` table via appointment_products embedding.
public struct AppointmentProductDetail: Decodable, Sendable {
    public let productId: UUID
    public let name: String
    public let price: Double
    public let imageUrl: String?

    public enum CodingKeys: String, CodingKey {
        case productId = "product_id"
        case name
        case price
        case imageUrl  = "image_url"
    }
}
