import Foundation

let json = """
[
 {"order_id":"fe2c8e74-688a-435b-b7c6-3d3a420520f2","rating":3}, 
 {"order_id":"d74e6f15-8574-4b4c-9233-66da815f93cd","rating":null}
]
""".data(using: .utf8)!

struct SARating: Identifiable, Decodable {
    let id: UUID
    let ratingValue: Int?

    enum CodingKeys: String, CodingKey {
        case id = "order_id"
        case ratingValue = "rating"
    }
}

do {
    let decoder = JSONDecoder()
    let decoded = try decoder.decode([SARating].self, from: json)
    print("Success: \(decoded)")
} catch {
    print("Error: \(error)")
}
