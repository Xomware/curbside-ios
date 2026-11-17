import SwiftUI

/// One card section: its sign pictogram on the left, the entries on the right.
struct HouseholdSection: View {
    let section: HouseholdModel.Section
    let editPerson: (Person) -> Void
    let editPet: (Pet) -> Void
    let deleteNote: (Note) -> Void

    private let year = Calendar.current.component(.year, from: .now)
    @ScaledMetric(relativeTo: .caption) private var dateColumn: CGFloat = 48

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            if let sign {
                SectionSign(kind: sign)
            }
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(title)
                    .font(CurbsideFont.label)
                    .foregroundStyle(Palette.inkSecondary)
                    .accessibilityAddTraits(.isHeader)
                entries
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(Spacing.md)
    }

    @ViewBuilder private var entries: some View {
        switch section {
        case .adults(let people), .kids(let people):
            ForEach(people) { person in
                Button { editPerson(person) } label: {
                    HStack(alignment: .top) {
                        Entry(title: person.name, detail: [person.born, person.notes].compactMap { $0 }.joined(separator: ". "))
                        if person.role == .kid, let age = person.age(in: year) {
                            AgeSign(age: age)
                        }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(SignPressStyle())
                .accessibilityHint("Edit")
            }
        case .pets(let pets):
            ForEach(pets) { pet in
                Button { editPet(pet) } label: {
                    Entry(title: pet.name, detail: [pet.species?.capitalized, pet.notes].compactMap { $0 }.joined(separator: ". "))
                        .contentShape(.rect)
                }
                .buttonStyle(SignPressStyle())
                .accessibilityHint("Edit")
            }
        case .notes(let notes):
            if notes.isEmpty {
                Entry(title: "No notes yet", detail: "")
            }
            ForEach(notes) { note in
                HStack(alignment: .firstTextBaseline, spacing: Spacing.md) {
                    Text("\(note.createdAt.isoDate?.formatted(.dateTime.month(.abbreviated).day()).uppercased() ?? "")\n\(note.source.rawValue.uppercased())")
                        .font(CurbsideFont.mono)
                        .foregroundStyle(Palette.inkSecondary)
                        .frame(width: dateColumn, alignment: .leading)
                    Text(note.text)
                        .font(CurbsideFont.body)
                        .foregroundStyle(Palette.ink)
                }
                .contextMenu {
                    Button("Delete note", systemImage: "trash", role: .destructive) { deleteNote(note) }
                }
                .accessibilityAction(named: "Delete note") { deleteNote(note) }
            }
        case .published:
            Entry(title: "From their card", detail: "They share their own details with you.")
        }
    }

    private var title: String {
        switch section {
        case .adults: "Adults"
        case .kids: "Kids"
        case .pets: "Pets"
        case .notes: "Notes"
        case .published: "Shared by them"
        }
    }

    private var sign: SectionSign.Kind? {
        switch section {
        case .adults: .adults
        case .kids: .kids
        case .pets: .pets
        case .notes: .notes
        case .published: nil
        }
    }
}

private struct Entry: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xxs) {
            Text(title)
                .font(CurbsideFont.signHeadline)
                .foregroundStyle(Palette.ink)
            if !detail.isEmpty {
                Text(detail)
                    .font(CurbsideFont.detail)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
