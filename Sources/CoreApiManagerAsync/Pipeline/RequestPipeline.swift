import Foundation

public struct RequestContext: Sendable {
    public var request: URLRequest
    public init(request: URLRequest) { self.request = request }
}

public protocol RequestInterceptor: Sendable {
    func prepare(_ context: RequestContext) async throws -> RequestContext
}

public struct RequestPipeline: Sendable {
    private let interceptors: [any RequestInterceptor]

    public init(interceptors: [any RequestInterceptor]) {
        self.interceptors = interceptors
    }

    public func run(_ request: URLRequest) async throws -> URLRequest {
        var ctx = RequestContext(request: request)
        for interceptor in interceptors {
            ctx = try await interceptor.prepare(ctx)
        }
        return ctx.request
    }
}
