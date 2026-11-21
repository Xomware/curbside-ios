import Contacts
import Foundation
import Testing
@testable import Curbside

private func person(phone: String? = nil, email: String? = nil) throws -> Person {
    var json = #"{"id": "01M7MYZ2HQV0211WPK9QDKNCXT", "name": "Juniper", "role": "adult", "birth_year_approx": false, "version": 2"#
    if let phone { json += #", "phone": "\#(phone)""# }
    if let email { json += #", "email": "\#(email)""# }
    return try JSONDecoder().decode(Person.self, from: Data((json + "}").utf8))
}

private func json(_ patch: Patch) throws -> NSDictionary? {
    try JSONSerialization.jsonObject(with: JSONEncoder().encode(patch)) as? NSDictionary
}

@Suite struct ContactsTests {
    @Test func phoneAndEmailRoundTripThroughTheDraft() throws {
        let saved = try person(phone: "(650) 555-0142", email: "juniper@example.com")
        let draft = PersonDraft(saved)
        #expect(draft.phone == "(650) 555-0142")
        #expect(draft.email == "juniper@example.com")
        #expect(draft.patch(from: saved).isEmpty)
    }

    @Test func addingAndClearingPatchesOnlyThoseFields() throws {
        var draft = PersonDraft(try person())
        draft.phone = " 650 555 0142 "
        draft.email = "juniper@example.com"
        #expect(try json(draft.patch(from: try person())) == ["version": 2, "phone": "650 555 0142", "email": "juniper@example.com"] as NSDictionary)

        let saved = try person(phone: "650 555 0142", email: "juniper@example.com")
        draft = PersonDraft(saved)
        draft.phone = ""
        draft.email = " "
        #expect(try json(draft.patch(from: saved)) == ["version": 2, "phone": NSNull(), "email": NSNull()] as NSDictionary)
    }

    @Test func createCarriesThemOnlyWhenSet() throws {
        var draft = PersonDraft()
        draft.name = "Odo"
        #expect(try JSONSerialization.jsonObject(with: JSONEncoder().encode(draft.create)) as? NSDictionary == ["name": "Odo", "role": "adult", "birth_year_approx": false] as NSDictionary)
        draft.email = "odo@example.com"
        let body = try JSONSerialization.jsonObject(with: JSONEncoder().encode(draft.create)) as? NSDictionary
        #expect(body?["email"] as? String == "odo@example.com")
    }

    @Test(arguments: [
        ("", "", nil),
        (String(repeating: "5", count: 40), "", nil),
        (String(repeating: "5", count: 41), "", "Phone runs past 40 characters."),
        ("", "odo@example.com", nil),
        ("", "odo.example.com", "Email should look like name@example.com."),
        ("", String(repeating: "o", count: 243) + "@example.com", "Email should look like name@example.com."),
    ] as [(String, String, String?)])
    func validationMatchesTheBackend(_ phone: String, _ email: String, _ problem: String?) {
        var draft = PersonDraft()
        draft.name = "Odo"
        draft.phone = phone
        draft.email = email
        #expect(draft.problem(thisYear: 2026) == problem)
    }

    @Test func aPickedContactFillsNamePhoneAndEmail() {
        let contact = CNMutableContact()
        contact.givenName = "Marguerite"
        contact.familyName = "Hobnob"
        contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "+1 650 555 0199"))]
        contact.emailAddresses = [CNLabeledValue(label: CNLabelHome, value: "marguerite@example.com" as NSString)]
        var draft = PersonDraft()
        draft.notes = "Two cats"
        draft.fill(from: contact)
        #expect(draft.name == "Marguerite")
        #expect(draft.phone == "+1 650 555 0199")
        #expect(draft.email == "marguerite@example.com")
        #expect(draft.notes == "Two cats")
    }

    @Test func aContactWithOnlyACompanyKeepsWhatWasTyped() {
        let contact = CNMutableContact()
        contact.organizationName = "Quillfeather Bakery"
        var draft = PersonDraft()
        draft.phone = "650 555 0100"
        draft.fill(from: contact)
        #expect(draft.name == "Quillfeather Bakery")
        #expect(draft.phone == "650 555 0100")
    }

    @Test func dialURLsKeepOnlyDialableCharacters() throws {
        let saved = try person(phone: "+1 (650) 555-0142", email: "juniper@example.com")
        #expect(saved.callURL?.absoluteString == "tel:+16505550142")
        #expect(saved.textURL?.absoluteString == "sms:+16505550142")
        #expect(saved.emailURL?.absoluteString == "mailto:juniper@example.com")
        #expect(try person(phone: "ask Barnaby").callURL == nil)
        #expect(try person().emailURL == nil)
    }

    @Test func theContactCardReadsBackAsAVCard() throws {
        let card = PersonCard(person: try person(phone: "650 555 0142", email: "juniper@example.com"))
        let contacts = try CNContactVCardSerialization.contacts(with: try card.vCard())
        let contact = try #require(contacts.first)
        #expect(contact.givenName == "Juniper")
        #expect(contact.phoneNumbers.first?.value.stringValue == "650 555 0142")
        #expect(contact.emailAddresses.first?.value as String? == "juniper@example.com")
    }
}
