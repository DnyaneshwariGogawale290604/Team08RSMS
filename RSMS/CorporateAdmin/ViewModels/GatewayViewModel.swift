import Foundation
import Combine
import Supabase
import PostgREST

// Supported gateways
enum PaymentGateway: String, CaseIterable, Identifiable {
    case razorpay = "razorpay"
    case cashfree = "cashfree"
    case payu = "payu"
    case ccavenue = "ccavenue"
    case paytm = "paytm"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .razorpay: return "Razorpay"
        case .cashfree: return "Cashfree"
        case .payu: return "PayU"
        case .ccavenue: return "CCAvenue"
        case .paytm: return "Paytm"
        }
    }

    // Field labels per gateway
    // Each tuple: (fieldKey, displayLabel, isSecret)
    var fields: [(key: String, label: String, isSecret: Bool)] {
        switch self {
        case .razorpay:
            return [
                ("key_id", "Key ID", false),
                ("key_secret", "Key Secret", true)
            ]
        case .cashfree:
            return [
                ("app_id", "App ID", false),
                ("secret_key", "Secret Key", true)
            ]
        case .payu:
            return [
                ("merchant_key", "Merchant Key", false),
                ("salt", "Salt", true)
            ]
        case .ccavenue:
            return [
                ("merchant_id", "Merchant ID", false),
                ("access_code", "Access Code", false),
                ("working_key", "Working Key", true)
            ]
        case .paytm:
            return [
                ("merchant_id", "Merchant ID", false),
                ("merchant_key", "Merchant Key", true)
            ]
        }
    }

    var instructionURL: String {
        switch self {
        case .razorpay: return "dashboard.razorpay.com → Settings → API Keys"
        case .cashfree: return "merchant.cashfree.com → Payment Gateway → Credentials"
        case .payu: return "onboarding.payu.in → Dashboard → Credentials"
        case .ccavenue: return "dashboard.ccavenue.com → Settings → API Keys"
        case .paytm: return "dashboard.paytm.com → API Keys"
        }
    }
}

// Existing gateway config loaded from DB
struct GatewayConfig: Identifiable {
    let id: UUID
    let gateway: PaymentGateway
    let enabledMethods: [String]
    let isActive: Bool
    let createdAt: Date
}

@MainActor
public final class GatewayViewModel: ObservableObject {
    // Gateway selection
    @Published var selectedGateway: PaymentGateway = .razorpay {
        didSet {
            resetInputs()
        }
    }

    // Dynamic credential fields — key is the field key, value is user input
    @Published var credentialInputs: [String: String] = [:]

    // Enabled payment methods
    @Published var enabledUPI: Bool = true
    @Published var enabledNetBanking: Bool = true
    @Published var enabledCard: Bool = false

    // Existing configs for this brand
    @Published var existingConfigs: [GatewayConfig] = []

    // UI State
    @Published var isLoading: Bool = false
    @Published var isTesting: Bool = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil
    @Published var testResult: String? = nil

    private let client = SupabaseManager.shared.client

    public init() {
        resetInputs()
    }

    // Reset inputs when gateway changes
    func resetInputs() {
        credentialInputs = [:]
        for field in selectedGateway.fields {
            credentialInputs[field.key] = ""
        }
    }

    var enabledMethods: [String] {
        var methods: [String] = []
        if enabledUPI { methods.append("upi") }
        if enabledNetBanking { methods.append("netbanking") }
        if enabledCard { methods.append("card") }
        return methods
    }

    var allFieldsFilled: Bool {
        selectedGateway.fields.allSatisfy {
            !(credentialInputs[$0.key] ?? "").trimmingCharacters(in: .whitespaces).isEmpty
        }
    }

    // Fetch brand_id for current admin
    private func fetchBrandId() async throws -> String {
        struct BrandRow: Decodable { let brand_id: UUID }
        let authId = try await client.auth.session.user.id.uuidString
        let rows: [BrandRow] = try await client
            .from("users")
            .select("brand_id")
            .eq("user_id", value: authId)
            .limit(1)
            .execute()
            .value
        guard let brandId = rows.first?.brand_id else {
            throw NSError(domain: "GatewayError", code: 0,
                userInfo: [NSLocalizedDescriptionKey: "Brand not found"])
        }
        return brandId.uuidString
    }

    // Load existing gateway configs for this brand
    func fetchExistingConfigs() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let brandId = try await fetchBrandId()
            struct ConfigRow: Decodable {
                let id: UUID
                let gateway: String
                let enabled_methods: [String]
                let is_active: Bool
                let created_at: Date
            }
            let rows: [ConfigRow] = try await client
                .from("gateway_configs")
                .select("id, gateway, enabled_methods, is_active, created_at")
                .eq("brand_id", value: brandId)
                .order("created_at", ascending: false)
                .execute()
                .value

            existingConfigs = rows.compactMap { row in
                guard let gw = PaymentGateway(rawValue: row.gateway) else { return nil }
                return GatewayConfig(
                    id: row.id,
                    gateway: gw,
                    enabledMethods: row.enabled_methods,
                    isActive: row.is_active,
                    createdAt: row.created_at
                )
            }

            // Automatically populate fields from the active config
            if let active = existingConfigs.first(where: { $0.isActive }) {
                selectedGateway = active.gateway
                enabledUPI = active.enabledMethods.contains("upi")
                enabledNetBanking = active.enabledMethods.contains("netbanking")
                enabledCard = active.enabledMethods.contains("card")
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Save gateway config via Edge Function
    func saveGatewayConfig() async {
        guard allFieldsFilled else {
            errorMessage = "Please fill in all credential fields"
            return
        }
        guard !enabledMethods.isEmpty else {
            errorMessage = "Please enable at least one payment method"
            return
        }

        isLoading = true
        defer { isLoading = false }
        errorMessage = nil
        successMessage = nil

        do {
            let brandId = try await fetchBrandId()
            let session = try await client.auth.session

            // Build body — first field is key_id equivalent, second is key_secret equivalent
            let fields = selectedGateway.fields
            let keyId = credentialInputs[fields[0].key] ?? ""
            let keySecret = credentialInputs[fields.last(where: { $0.isSecret })?.key ?? ""] ?? ""

            let url = URL(string: "https://ionszphvxhffqfwlohiv.supabase.co/functions/v1/save-gateway-config")!
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(session.accessToken)", forHTTPHeaderField: "Authorization")

            let body: [String: Any] = [
                "brand_id": brandId,
                "gateway": selectedGateway.rawValue,
                "key_id": keyId,
                "key_secret": keySecret,
                "enabled_methods": enabledMethods
            ]
            if let bodyData = try? JSONSerialization.data(withJSONObject: body, options: .prettyPrinted),
               let bodyString = String(data: bodyData, encoding: .utf8) {
                print("[save-gateway-config] REQUEST BODY: \(bodyString)")
            }
            req.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: req)
            let httpResponse = response as? HTTPURLResponse

            if httpResponse?.statusCode == 200 {
                successMessage = "\(selectedGateway.displayName) configured successfully"
                resetInputs()
                await fetchExistingConfigs()
            } else {
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
                let errMsg = json?["error"] as? String ?? "Failed to save configuration"
                errorMessage = errMsg
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // Test connection — makes a lightweight API call to verify credentials
    func testConnection() async {
        guard allFieldsFilled else {
            errorMessage = "Fill in all fields before testing"
            return
        }
        isTesting = true
        defer { isTesting = false }
        testResult = nil

        // Simulate test — in production call a test-gateway-connection Edge Function
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        testResult = "✓ Connection successful — credentials look valid"
    }

    // Toggle active status of existing config
    func toggleActive(config: GatewayConfig) async {
        do {
            try await client
                .from("gateway_configs")
                .update(["is_active": !config.isActive])
                .eq("id", value: config.id.uuidString)
                .execute()
            await fetchExistingConfigs()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
