import Foundation

enum Config {
    static let apiBaseURL = url("CurbsideAPIHost")
    static let cognito = Cognito(domain: url("CurbsideCognitoDomain"), clientID: value("CurbsideCognitoClientID"))

    // Debug builds carry the development aps-environment (project.yml), so their device tokens only work on the sandbox.
    #if DEBUG
    static let apnsEnvironment = "sandbox"
    #else
    static let apnsEnvironment = "production"
    #endif

    private static func value(_ key: String) -> String {
        guard let value = Bundle.main.object(forInfoDictionaryKey: key) as? String, !value.isEmpty else {
            fatalError("\(key) missing from Info.plist; set its CURBSIDE_* build setting in project.yml")
        }
        return value
    }

    private static func url(_ key: String) -> URL {
        guard let url = URL(string: "https://\(value(key))") else {
            fatalError("\(key) is not a host name")
        }
        return url
    }
}
