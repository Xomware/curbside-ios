import MapKit
import SwiftUI

/// "Where do you live?" Makes a street around your home with your household on it, or, after an invite, adds your
/// household to that street.
struct HomeStep: View {
    @Bindable var model: FirstRunModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                StepLabel(number: 2)
                StreetSign(name: model.isJoining ? model.place?.name ?? "Your street" : "Your home")
                Text(model.isJoining
                    ? "Add your home to this street? Everyone on it sees it. You can skip this and add it later."
                    : "Your street map starts around your home and outlines the houses nearby. Only people you invite can see it.")
                    .font(CurbsideFont.body)
                    .foregroundStyle(Palette.ink)
                HomePreview(found: model.found, label: model.label, radius: model.isJoining ? nil : FirstRunModel.radius)
                SignButton(title: "Use my location") { Task { await model.useMyLocation() } }
                field("Or search your address", text: $model.query, content: .fullStreetAddress)
                    .onSubmit { Task { await model.search() } }
                    .submitLabel(.search)
                if let found = model.found {
                    Text("FOUND  \(found.address?.uppercased() ?? "YOUR PIN")")
                        .font(CurbsideFont.label)
                        .foregroundStyle(Palette.inkSecondary)
                }
                field("Name on your sign", text: $model.label, content: .familyName)
                Text("Your family name works well, like \"Rivera\".")
                    .font(CurbsideFont.detail)
                    .foregroundStyle(Palette.inkSecondary)
                if !model.isJoining {
                    field("Street name", text: $model.street, content: .streetAddressLine1)
                }
                if let message = model.message {
                    Text(message)
                        .font(CurbsideFont.detail)
                        .foregroundStyle(Palette.ink)
                }
                SignButton(title: model.isJoining ? "Add my home" : "Put me on the map") { Task { await model.saveHome() } }
                    .disabled(!model.canSaveHome)
                    .opacity(model.canSaveHome ? 1 : 0.5)
                if model.isJoining {
                    SkipButton(title: "Skip for now", action: model.skipHome)
                }
            }
            .padding(Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .disabled(model.isBusy)
    }

    /// Labelled above, not only by placeholder: the sign and street fields arrive filled in.
    private func field(_ title: String, text: Binding<String>, content: UITextContentType) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(title.uppercased())
                .font(CurbsideFont.label)
                .foregroundStyle(Palette.inkSecondary)
                .accessibilityHidden(true)
            TextField(title, text: text)
                .font(CurbsideFont.body)
                .textContentType(content)
                .padding(Spacing.md)
                .background(Palette.surface, in: .rect(cornerRadius: 8))
        }
    }
}

/// Your home's plaque where it was found, and the street's reach around it when one is being made.
private struct HomePreview: View {
    let found: Spot?
    let label: String
    let radius: Int?

    var body: some View {
        Map(position: .constant(position), interactionModes: []) {
            if let found {
                if let radius {
                    MapCircle(center: found.coordinate, radius: CLLocationDistance(radius))
                        .foregroundStyle(Palette.signGreen.opacity(0.15))
                        .stroke(Palette.signGreen, lineWidth: 2)
                }
                Annotation("Your home", coordinate: found.coordinate) {
                    HousePlaque(number: found.address.flatMap(Household.houseNumber), name: RootModel.validName(label), size: .pin)
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .frame(height: 200)
        .clipShape(.rect(cornerRadius: 8))
        .accessibilityLabel(found == nil ? "Map, no home chosen yet" : "Map around your home")
    }

    private var position: MapCameraPosition {
        guard let found else { return .automatic }
        let span = CLLocationDistance((radius ?? 100) * 3)
        return .region(MKCoordinateRegion(center: found.coordinate, latitudinalMeters: span, longitudinalMeters: span))
    }
}
