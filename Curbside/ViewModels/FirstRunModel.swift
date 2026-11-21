import CoreLocation
import Foundation
import Observation

/// After the display name: where you live, who lives with you, then a short tour. With no street yet the home step
/// makes one around your home; joining by invite turns it into an optional "add your home to this street".
@MainActor @Observable
final class FirstRunModel {
    enum Step: Equatable {
        case home
        case people
        case tour
        case done
    }

    enum Kind: String, CaseIterable, Identifiable {
        case adult, kid, pet

        var id: String { rawValue }
    }

    struct Member: Equatable, Identifiable {
        let id = UUID()
        let name: String
        let kind: Kind
    }

    nonisolated static let touredKey = "toured"
    nonisolated static let radius = 300

    private(set) var step = Step.home
    /// True once an invite put the account on a street: the home goes on that street instead of a new one.
    private(set) var isJoining = false
    /// The street made or joined. Kept across a failed household save, so a retry doesn't make a second street.
    private(set) var place: Place?
    private(set) var home: Household?
    private(set) var found: Spot?
    private(set) var added: [Member] = []
    private(set) var isBusy = false
    private(set) var message: String?

    var label: String
    var street = ""
    var query = ""
    var name = ""
    var kind = Kind.adult

    private let api: APIClient
    private let geo: Geo
    private let defaults: UserDefaults

    init(api: APIClient, displayName: String, geo: Geo = .live, defaults: UserDefaults = .standard) {
        self.api = api
        self.geo = geo
        self.defaults = defaults
        label = "\(displayName)'s"
    }

    var canSaveHome: Bool {
        found != nil && RootModel.validName(label) != nil && (isJoining || RootModel.validName(street) != nil) && !isBusy
    }

    /// An invite accepted during the home step: put the home on that street. Later steps are already past it.
    func join(_ place: Place) {
        guard step == .home, home == nil else { return }
        self.place = place
        isJoining = true
    }

    func useMyLocation() async {
        await pick {
            let coordinate = try await geo.locate()
            return (coordinate, await geo.address(coordinate))
        }
    }

    func search() async {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        await pick { try await geo.search(query) }
    }

    func saveHome() async {
        guard let found, let label = RootModel.validName(label) else { return }
        let street = RootModel.validName(street)
        guard place != nil || street != nil else { return }
        isBusy = true
        defer { isBusy = false }
        message = nil
        do {
            if place == nil, let street {
                let body = NewPlace(name: street, center: .init(lat: found.lat, lng: found.lng), radiusM: Self.radius)
                place = try await api.request("/v1/maps", method: "POST", body: body) as Place
            }
            guard let place else { return }
            let body = NewHousehold(label: label, address: found.address, lat: found.lat, lng: found.lng, buildingID: nil)
            let home: Household = try await api.request("/v1/maps/\(place.id)/households", method: "POST", body: body)
            self.home = home
            defaults.set(home.id, forKey: MapHomeModel.homeKey)
            step = .people
        } catch {
            message = "Couldn't save your home. Try again."
        }
    }

    /// Joining only: no home, so nobody to add; straight to the tour.
    func skipHome() {
        finishPeople()
    }

    func addMember() async {
        guard let place, let home, let name = RootModel.validName(name) else { return }
        isBusy = true
        defer { isBusy = false }
        message = nil
        let path = "/v1/maps/\(place.id)/households/\(home.id)"
        do {
            if kind == .pet {
                var draft = PetDraft()
                draft.name = name
                let _: Pet = try await api.request("\(path)/pets", method: "POST", body: draft.create)
            } else {
                var draft = PersonDraft()
                draft.name = name
                draft.role = kind == .kid ? .kid : .adult
                let _: Person = try await api.request("\(path)/people", method: "POST", body: draft.create)
            }
            added.append(Member(name: name, kind: kind))
            self.name = ""
        } catch {
            message = "Couldn't add \(name). Try again."
        }
    }

    func finishPeople() {
        message = nil
        step = defaults.bool(forKey: Self.touredKey) ? .done : .tour
    }

    func finishTour() {
        defaults.set(true, forKey: Self.touredKey)
        step = .done
    }

    private func pick(_ find: () async throws -> (CLLocationCoordinate2D, String?)) async {
        isBusy = true
        defer { isBusy = false }
        message = nil
        do {
            let (coordinate, address) = try await find()
            var spot = Spot(coordinate, buildingID: nil)
            spot.address = address
            found = spot
            if street.isEmpty, let address { street = Geo.street(from: address) }
        } catch Geo.Failure.denied {
            message = "Location is off for Curbside. Search for your address instead, or turn it on in Settings."
        } catch Geo.Failure.notFound {
            message = "No match for that address."
        } catch {
            message = "Couldn't find that. Try again."
        }
    }
}

private struct NewPlace: Encodable, Sendable {
    let name: String
    let center: Place.Center
    let radiusM: Int

    enum CodingKeys: String, CodingKey {
        case name, center
        case radiusM = "radius_m"
    }
}
