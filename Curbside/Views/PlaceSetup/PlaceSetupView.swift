import MapKit
import SwiftUI

/// First run: center a place on your street, choose how far it reaches, name it.
struct PlaceSetupView: View {
    let created: (Place) -> Void

    @State private var model: PlaceSetupModel

    init(api: APIClient, created: @escaping (Place) -> Void) {
        self.created = created
        _model = State(initialValue: PlaceSetupModel(api: api))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                StreetSign(name: "New place")
                Text("Center the map on your street. Curbside outlines the houses around it.")
                    .font(CurbsideFont.body)
                    .foregroundStyle(Palette.ink)
                RadiusPreview(center: model.center, radius: model.radius)
                SignButton(title: "Use my location") { Task { await model.useMyLocation() } }
                field("Or search an address", text: $model.query, content: .fullStreetAddress)
                    .onSubmit { Task { await model.search() } }
                    .submitLabel(.search)
                Picker("How far", selection: $model.radius) {
                    ForEach(PlaceSetupModel.radii, id: \.self) { Text("\($0) m") }
                }
                .pickerStyle(.segmented)
                field("Place name", text: $model.name, content: .streetAddressLine1)
                if let message = model.message {
                    Text(message)
                        .font(CurbsideFont.detail)
                        .foregroundStyle(Palette.ink)
                }
                SignButton(title: "Make the map") {
                    Task {
                        if let place = await model.create() { created(place) }
                    }
                }
                .disabled(!model.canCreate)
                .opacity(model.canCreate ? 1 : 0.5)
            }
            .padding(Spacing.md)
        }
        .scrollDismissesKeyboard(.interactively)
        .disabled(model.isBusy)
    }

    private func field(_ title: String, text: Binding<String>, content: UITextContentType) -> some View {
        TextField(title, text: text)
            .font(CurbsideFont.body)
            .textContentType(content)
            .padding(Spacing.md)
            .background(Palette.surface, in: .rect(cornerRadius: 8))
    }
}

/// The chosen center with its radius drawn on, or the whole country until there is one.
private struct RadiusPreview: View {
    let center: CLLocationCoordinate2D?
    let radius: Int

    var body: some View {
        Map(position: .constant(position), interactionModes: []) {
            if let center {
                MapCircle(center: center, radius: CLLocationDistance(radius))
                    .foregroundStyle(Palette.signGreen.opacity(0.15))
                    .stroke(Palette.signGreen, lineWidth: 2)
            }
        }
        .mapStyle(.standard(emphasis: .muted, pointsOfInterest: .excludingAll))
        .frame(height: 200)
        .clipShape(.rect(cornerRadius: 8))
        .accessibilityLabel(center == nil ? "Map, no place chosen yet" : "Map of your place, reaching \(radius) meters from the center")
    }

    private var position: MapCameraPosition {
        guard let center else { return .automatic }
        let span = CLLocationDistance(radius * 3)
        return .region(MKCoordinateRegion(center: center, latitudinalMeters: span, longitudinalMeters: span))
    }
}
