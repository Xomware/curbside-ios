import SwiftUI

/// Reach a saved person: call, text or email them, or pass them on as a contact card.
struct PersonContactSection: View {
    let person: Person

    var body: some View {
        Section("Get in touch") {
            if let url = person.callURL, let phone = person.phone {
                Link(destination: url) { Label(phone, systemImage: "phone") }
                    .accessibilityLabel("Call \(person.name)")
            }
            if let url = person.textURL {
                Link(destination: url) { Label("Text \(person.name)", systemImage: "message") }
            }
            if let url = person.emailURL, let email = person.email {
                Link(destination: url) { Label(email, systemImage: "envelope") }
                    .accessibilityLabel("Email \(person.name)")
            }
            ShareLink(item: PersonCard(person: person), preview: SharePreview(person.name)) {
                Label("Share contact card", systemImage: "square.and.arrow.up")
            }
        }
    }
}
