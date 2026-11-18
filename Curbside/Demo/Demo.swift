import Foundation

/// `-demo <scenario>` launch argument: signed in, with every API call answered from the `demo-*` fixtures beside
/// this file. Screenshots and UI tests use it because nobody can sign in on a simulator. Release builds exclude this
/// folder (`EXCLUDED_SOURCE_FILE_NAMES` in project.yml), so the call site is `#if DEBUG`.
enum Demo {
    /// `street` (the default) is a loaded block; `new` is an account with no place yet.
    static var scenario: String? {
        let args = ProcessInfo.processInfo.arguments
        guard let flag = args.firstIndex(of: "-demo") else { return nil }
        return args.indices.contains(flag + 1) ? args[flag + 1] : "street"
    }

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
        return RootModel(auth: auth, api: APIClient(baseURL: Config.apiBaseURL, tokens: auth, session: session), lock: lock)
    }

    /// Fixture file for a request, keyed by method and path with ids replaced by `{id}`.
    static func fixture(for request: URLRequest) -> String? {
        if request.url?.host() == "footprints.demo.invalid" { return "demo-footprints.geojson.gz" }
        let path = (request.url?.path() ?? "").replacing(/\/[0-9A-HJKMNP-TV-Z]{26}/, with: "/{id}")
        switch (scenario, request.httpMethod ?? "GET", path) {
        case (_, "GET", "/v1/me"): return "demo-me.json"
        case (_, "GET", "/v1/me/export"): return "demo-export.json"
        case ("new", "GET", "/v1/maps"): return "demo-maps-none.json"
        case (_, "GET", "/v1/maps"): return "demo-maps.json"
        case (_, "GET", "/v1/maps/{id}"): return "demo-map.json"
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
        let url = Demo.fixture(for: request).flatMap { Bundle.main.url(forResource: $0, withExtension: nil) }
        let body = url.flatMap { try? Data(contentsOf: $0) } ?? Data(#"{"data": null, "error": {"code": "demo_missing", "message": "No demo fixture"}, "meta": {}}"#.utf8)
        let response = HTTPURLResponse(url: request.url ?? Config.apiBaseURL, statusCode: url == nil ? 404 : 200, httpVersion: nil, headerFields: nil)
        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
