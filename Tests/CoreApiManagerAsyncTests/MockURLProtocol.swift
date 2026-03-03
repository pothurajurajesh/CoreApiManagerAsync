import Foundation

final class MockURLProtocol: URLProtocol {
    private static let lock = NSLock()
    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let handlerCopy: ((URLRequest) throws -> (HTTPURLResponse, Data))? = {
            Self.lock.lock()
            defer { Self.lock.unlock() }
            return Self.handler
        }()

        guard let handler = handlerCopy else {
            fatalError("MockURLProtocol.handler not set")
        }

        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
