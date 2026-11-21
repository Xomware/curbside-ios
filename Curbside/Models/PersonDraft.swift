import Contacts
import Foundation

/// The person editor's form state, kept as the user typed it. Converts to a create body or a PATCH diff.
struct PersonDraft: Equatable {
    var name = ""
    var role = Person.Role.adult
    var birthYear = ""
    var approx = false
    var notes = ""
    var phone = ""
    var email = ""

    init() {}

    init(_ person: Person) {
        name = person.name
        role = person.role
        birthYear = person.birthYear.map(String.init) ?? ""
        approx = person.birthYearApprox
        notes = person.notes ?? ""
        phone = person.phone ?? ""
        email = person.email ?? ""
    }

    /// Takes what the Contacts picker hands back. A field the contact lacks keeps what was typed. Reading a key the
    /// contact wasn't fetched with raises an Objective-C exception, so each is checked first.
    mutating func fill(from contact: CNContact) {
        if contact.areKeysAvailable([CNContactGivenNameKey, CNContactFamilyNameKey, CNContactOrganizationNameKey] as [CNKeyDescriptor]) {
            let full = [contact.givenName, contact.familyName].filter { !$0.isEmpty }.joined(separator: " ")
            if let picked = RootModel.validName(contact.givenName) ?? RootModel.validName(full) ?? RootModel.validName(contact.organizationName) {
                name = picked
            }
        }
        if contact.isKeyAvailable(CNContactPhoneNumbersKey), let number = contact.phoneNumbers.first {
            phone = number.value.stringValue
        }
        if contact.isKeyAvailable(CNContactEmailAddressesKey), let address = contact.emailAddresses.first {
            email = address.value as String
        }
    }

    /// Why the form can't be saved, or nil when it can. Limits match the backend's `PersonCreate`.
    func problem(thisYear: Int = Calendar.current.component(.year, from: .now)) -> String? {
        if RootModel.validName(name) == nil { return "Add a name." }
        if !trimmed(birthYear).isEmpty, !(1900...thisYear).contains(Int(trimmed(birthYear)) ?? 0) {
            return "Birth year should be between 1900 and \(thisYear)."
        }
        if trimmed(notes).count > 1000 { return "Notes run past 1,000 characters." }
        if trimmed(phone).count > 40 { return "Phone runs past 40 characters." }
        if let mail, mail.count > 254 || !mail.contains("@") { return "Email should look like name@example.com." }
        return nil
    }

    var create: NewPerson {
        NewPerson(name: trimmed(name), role: role, birthYear: year, birthYearApprox: approx, notes: note, phone: optional(phone), email: mail)
    }

    func patch(from person: Person) -> Patch {
        var patch = Patch(version: person.version)
        patch.set("name", person.name, trimmed(name), as: Patch.Value.string)
        patch.set("role", person.role.rawValue, role.rawValue, as: Patch.Value.string)
        patch.set("birth_year", person.birthYear, year, as: Patch.Value.nullable)
        patch.set("birth_year_approx", person.birthYearApprox, approx, as: Patch.Value.bool)
        patch.set("notes", person.notes, note, as: Patch.Value.nullable)
        patch.set("phone", person.phone, optional(phone), as: Patch.Value.nullable)
        patch.set("email", person.email, mail, as: Patch.Value.nullable)
        return patch
    }

    private var year: Int? { Int(trimmed(birthYear)) }
    private var note: String? { optional(notes) }
    private var mail: String? { optional(email) }

    private func optional(_ text: String) -> String? {
        trimmed(text).isEmpty ? nil : trimmed(text)
    }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct NewPerson: Encodable, Sendable {
    let name: String
    let role: Person.Role
    let birthYear: Int?
    let birthYearApprox: Bool
    let notes: String?
    let phone: String?
    let email: String?

    enum CodingKeys: String, CodingKey {
        case name, role, notes, phone, email
        case birthYear = "birth_year"
        case birthYearApprox = "birth_year_approx"
    }
}
