import Foundation

/// S3 serves the gzipped footprint file with `Content-Encoding: gzip` when the uploader set it, and URLSession
/// inflates it. When it didn't, the bytes arrive still gzipped; Foundation only inflates raw DEFLATE, so the gzip
/// header and trailer (RFC 1952) come off here first.
enum Gzip {
    static func inflateIfNeeded(_ data: Data) throws -> Data {
        let bytes = [UInt8](data)
        guard bytes.count > 18, bytes[0] == 0x1F, bytes[1] == 0x8B, bytes[2] == 8 else { return data }
        // Python's gzip.compress sets no flags; the gzip CLI sets FNAME. Nothing else writes these files.
        let flags = bytes[3]
        guard flags & ~0x08 == 0 else { throw APIError.malformed }
        var start = 10
        if flags & 0x08 != 0 {
            guard let end = bytes[start...].firstIndex(of: 0) else { throw APIError.malformed }
            start = end + 1
        }
        guard start < bytes.count - 8 else { throw APIError.malformed }
        let deflated = Data(bytes[start..<(bytes.count - 8)])
        return try (deflated as NSData).decompressed(using: .zlib) as Data
    }
}
