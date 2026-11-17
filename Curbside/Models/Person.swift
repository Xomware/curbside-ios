/// An adult or kid in a household. Optional fields are absent from the API, not null, when unset.
struct Person: Decodable, Equatable, Identifiable, Sendable {
    enum Role: String, Codable, Sendable {
        case adult, kid
    }

    let id: String
    var version: Int
    var name: String
    var role: Role
    var birthYear: Int?
    /// "About 6" from a capture: the year is a guess.
    var birthYearApprox: Bool
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id, version, name, role, notes
        case birthYear = "birth_year"
        case birthYearApprox = "birth_year_approx"
    }

    /// "8", or "~5" for a guessed year. Nil without a birth year.
    func age(in year: Int) -> String? {
        birthYear.map { (birthYearApprox ? "~" : "") + String(year - $0) }
    }

    /// "Born 2018", or "Born ~2021, a guess".
    var born: String? {
        birthYear.map { birthYearApprox ? "Born ~\($0), a guess" : "Born \($0)" }
    }
}
