import Contacts
import CoreTransferable
import UniformTypeIdentifiers

/// A person as a `.vcf` for the share sheet: name, phone and email. Notes stay in Curbside.
struct PersonCard: Transferable {
    let person: Person

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .vCard) { try $0.vCard() }
            .suggestedFileName { "\($0.person.name).vcf" }
    }

    func vCard() throws -> Data {
        let contact = CNMutableContact()
        contact.givenName = person.name
        if let phone = person.phone {
            contact.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: phone))]
        }
        if let email = person.email {
            contact.emailAddresses = [CNLabeledValue(label: CNLabelHome, value: email as NSString)]
        }
        return try CNContactVCardSerialization.data(with: [contact])
    }
}
