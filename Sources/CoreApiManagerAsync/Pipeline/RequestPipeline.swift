import Foundation

public struct RequestContext: Sendable {
    public var request: URLRequest
    public init(request: URLRequest) { self.request = request }
}

public protocol RequestInterceptor: Sendable {
    func prepare(_ context: RequestContext) async throws -> RequestContext
}

public struct RequestPipeline: Sendable {
    private let interceptors: [RequestInterceptor]

    public init(interceptors: [RequestInterceptor]) {
        self.interceptors = interceptors
    }

    public func run(_ request: URLRequest) async throws -> URLRequest {
        var context = RequestContext(request: request)
        for i in interceptors {
            context = try await i.prepare(context)
        }
        return context.request
    }
}
