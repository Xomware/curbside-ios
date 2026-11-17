import Foundation

enum Config {
    static let apiBaseURL: URL = {
        guard let host = Bundle.main.object(forInfoDictionaryKey: "CurbsideAPIHost") as? String,
              let url = URL(string: "https://\(host)") else {
            fatalError("CurbsideAPIHost missing from Info.plist; set CURBSIDE_API_HOST in project.yml")
        }
        return url
    }()
}
