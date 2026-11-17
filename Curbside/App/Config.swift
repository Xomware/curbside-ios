import Foundation

enum Config {
    static let apiBaseURL = url("CurbsideAPIHost")
    static let cognito = Cognito(domain: url("CurbsideCognitoDomain"), clientID: value("CurbsideCognitoClientID"))

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
