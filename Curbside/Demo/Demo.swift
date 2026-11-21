import Foundation

/// `-demo <scenario>` launch argument: signed in, with every API call answered from the `demo-*` fixtures beside
/// this file. Screenshots and UI tests use it because nobody can sign in on a simulator. Release builds exclude this
/// folder (`EXCLUDED_SOURCE_FILE_NAMES` in project.yml), so the call site is `#if DEBUG`.
enum Demo {
    /// `street` (the default) is a loaded block, plus a second street shared with the demo account; `new` is an account
    /// with no place yet; `onboarding` is a sign-in with no account. `-invite <code>` opens an invite link on launch;
    /// `usedInvite` is the one that's spent.
    static var scenario: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let flag = args.firstIndex(of: "-demo") else { return nil }
        return args.indices.contains(flag + 1) ? args[flag + 1] : "street"
    }

    static let sharedMapID = "01JDEM0MAP0000000000000002"
    static let usedInvite = "SPENT00000"

    @MainActor static func rootModel() -> RootModel {
        let store = KeychainTokenStore(service: "com.Xomware.Curbside.demo")
        // The ID token carries a sub so settings can mark "Signed in on this iPhone"; nothing verifies it.
        try? store.save(Tokens(access: "demo", id: "e30.eyJzdWIiOiJkZW1vLWdvb2dsZSIsImNvZ25pdG86dXNlcm5hbWUiOiJHb29nbGVfZGVtbyJ9.demo", refresh: "demo"))
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [DemoURLProtocol.self]
        let session = URLSession(configuration: config)
        let auth = AuthSession(cognito: Config.cognito, store: store, session: session)
        // Screenshots run unattended, so the demo locks only with `-lock`. Its own suite keeps the real setting untouched.
        let defaults = UserDefaults(suiteName: "com.Xomware.Curbside.demo") ?? .standard
        defaults.set(ProcessInfo.processInfo.arguments.contains("-lock"), forKey: AppLock.key)
        let lock = AppLock(defaults: defaults)
        // Every run opens on the first street, whichever one the last run switched to.
        defaults.removeObject(forKey: MapHomeModel.openKey)
        let root = RootModel(auth: auth, api: APIClient(baseURL: Config.apiBaseURL, tokens: auth, session: session), lock: lock, defaults: defaults)
        let args = ProcessInfo.processInfo.arguments
        if let flag = args.firstIndex(of: "-invite"), args.indices.contains(flag + 1) {
            root.pendingInvite = InviteLink(code: args[flag + 1])
        }
        return root
    }

    /// Fixture file for a request, keyed by method and path with ids replaced by `{id}`.
    static func fixture(for request: URLRequest) -> String? {
        if request.url?.host() == "footprints.demo.invalid" { return "demo-footprints.geojson.gz" }
        let path = (request.url?.path() ?? "")
            .replacing(/\/[0-9A-HJKMNP-TV-Z]{26}/, with: "/{id}")
            .replacing(/\/invites\/[0-9A-HJKMNP-TV-Z]{10}/, with: "/invites/{code}")
            .replacing(/\/devices\/[0-9a-f]+/, with: "/devices/{token}")
        let shared = request.url?.path().contains(sharedMapID) == true
        switch (scenario, request.httpMethod ?? "GET", path) {
        case ("onboarding", "GET", "/v1/me"): return "demo-me.404.json"
        case (_, "GET", "/v1/me"): return "demo-me.json"
        case (_, "GET", "/v1/me/export"): return "demo-export.json"
        case ("new", "GET", "/v1/maps"): return "demo-maps-none.json"
        case (_, "GET", "/v1/maps"): return "demo-maps.json"
        case (_, "GET", "/v1/maps/{id}"): return shared ? "demo-map-shared.json" : "demo-map.json"
        case (_, "GET", "/v1/maps/{id}/members"): return shared ? "demo-members-shared.json" : "demo-members.json"
        case (_, "DELETE", "/v1/maps/{id}/members/{id}"): return "demo-member-removed.json"
        case (_, "POST", "/v1/maps/{id}/invites"): return "demo-invite-created.json"
        case (_, "GET", "/v1/invites/{code}"): return request.url?.lastPathComponent == usedInvite ? "demo-invite.404.json" : "demo-invite.json"
        case (_, "POST", "/v1/invites/{code}/accept"): return "demo-invite-accepted.json"
        case (_, "PATCH", "/v1/me"): return "demo-me.json"
        case (_, "GET", "/v1/activity"): return "demo-activity.json"
        case (_, "POST", "/v1/activity/seen"), (_, "PUT", "/v1/devices/{token}"), (_, "DELETE", "/v1/devices/{token}"): return "demo-empty.204.json"
        case (_, "GET", "/v1/maps/{id}/footprints"): return "demo-footprints-info.json"
        case (_, "POST", "/v1/maps"): return "demo-map-created.json"
        case (_, "POST", "/v1/maps/{id}/households"): return "demo-household-created.json"
        case (_, "POST", "/v1/maps/{id}/capture/parse"): return "demo-capture-parse.json"
        case (_, "POST", "/v1/maps/{id}/capture/apply"): return "demo-capture-apply.json"
        case (_, "GET", "/v1/maps/{id}/households/{id}"): return "demo-household-\(request.url?.lastPathComponent ?? "").json"
        default: return nil
        }
    }
}

final class DemoURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        // A missing route answers 404 so the screen under test shows its error state instead of hanging.
        // A `*.404.json` fixture is an API error body, answered with its status; a `*.204.json` is an empty answer.
        let url = Demo.fixture(for: request).flatMap { Bundle.main.url(forResource: $0, withExtension: nil) }
        let body = url.flatMap { try? Data(contentsOf: $0) } ?? Data(#"{"data": null, "error": {"code": "demo_missing", "message": "No demo fixture"}, "meta": {}}"#.utf8)
        let status = url.map { name in
            name.lastPathComponent.hasSuffix(".404.json") ? 404 : name.lastPathComponent.hasSuffix(".204.json") ? 204 : 200
        } ?? 404
        let response = HTTPURLResponse(url: request.url ?? Config.apiBaseURL, statusCode: status, httpVersion: nil, headerFields: nil)
        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
