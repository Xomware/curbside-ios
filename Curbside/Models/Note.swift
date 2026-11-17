import Foundation

/// A logged conversation or fact. Notes have no version: they are created and deleted, never edited.
struct Note: Decodable, Equatable, Identifiable, Sendable {
    enum Source: String, Codable, Sendable {
        case voice, text, manual
    }

    let id: String
    let text: String
    let source: Source
    let createdAt: String

    enum CodingKeys: String, CodingKey {
        case id, text, source
        case createdAt = "created_at"
    }
}

extension String {
    /// The backend's `2026-11-17T14:35:52+00:00` timestamps.
    var isoDate: Date? {
        try? Date(self, strategy: .iso8601)
    }
}
