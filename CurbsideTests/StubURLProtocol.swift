import Foundation
import Synchronization

/// Answers every request from a queue of canned responses. Suites using it must be `.serialized`.
final class StubURLProtocol: URLProtocol {
    struct Reply {
        let status: Int
        let body: String
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
        let reply = Self.replies.withLock { $0.removeFirst() }
        let response = HTTPURLResponse(url: request.url!, statusCode: reply.status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(reply.body.utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
