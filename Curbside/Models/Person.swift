import Foundation

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
    var phone: String?
    var email: String?

    enum CodingKeys: String, CodingKey {
        case id, version, name, role, notes, phone, email
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

    var callURL: URL? { dial("tel") }
    var textURL: URL? { dial("sms") }

    var emailURL: URL? {
        guard let email else { return nil }
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = email
        return components.url
    }

    /// Spaces, dashes and brackets break `tel:` URLs; only what a keypad can dial stays.
    private func dial(_ scheme: String) -> URL? {
        let number = (phone ?? "").filter { ($0.isASCII && $0.isNumber) || "+*#,".contains($0) }
        return number.isEmpty ? nil : URL(string: "\(scheme):\(number)")
    }
}
