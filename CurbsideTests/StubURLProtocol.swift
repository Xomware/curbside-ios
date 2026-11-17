import Foundation
import Synchronization
import Testing

/// Suites that use `StubURLProtocol` nest in here: its queues are global, so they must not run in parallel.
@Suite(.serialized) enum StubbedNetwork {}

/// Answers every request from a queue of canned responses. Suites using it nest in `StubbedNetwork`.
final class StubURLProtocol: URLProtocol {
    struct Reply {
        let status: Int
        let data: Data

        init(status: Int, body: String) {
            self.init(status: status, data: Data(body.utf8))
        }

        init(status: Int, data: Data) {
            self.status = status
            self.data = data
        }

        var body: String { String(decoding: data, as: UTF8.self) }
    }

    static let replies = Mutex<[Reply]>([])
    static let requests = Mutex<[URLRequest]>([])

    static func session(_ replies: [Reply]) -> URLSession {
        self.replies.withLock { $0 = replies }
        requests.withLock { $0 = [] }
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubURLProtocol.self]
        return URLSession(configuration: config)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.withLock { $0.append(request) }
        // An unplanned request fails the test through its assertions instead of crashing the host app.
        let reply = Self.replies.withLock { $0.isEmpty ? Reply(status: 599, body: "no stub") : $0.removeFirst() }
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: reply.data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    /// URLSession hands protocols the body as a stream, so `httpBody` is nil by the time it is recorded.
    static func body(of request: URLRequest) -> String {
        guard let stream = request.httpBodyStream else { return "" }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return String(decoding: data, as: UTF8.self)
    }
}
