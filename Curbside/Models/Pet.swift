struct Pet: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    var version: Int
    var name: String
    var species: String?
    var notes: String?
}
