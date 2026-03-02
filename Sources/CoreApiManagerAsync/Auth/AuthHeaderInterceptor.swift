import Foundation

public struct AuthHeaderInterceptor: RequestInterceptor {
    private let tokenActor: AuthTokenActor
    private let headerName: String

    public init(tokenActor: AuthTokenActor, headerName: String = "Authorization") {
        self.tokenActor = tokenActor
        self.headerName = headerName
    }

    public func prepare(_ context: RequestContext) async throws -> RequestContext {
        var ctx = context
        if let token = await tokenActor.currentToken() {
            ctx.request.setValue("Bearer \(token)", forHTTPHeaderField: headerName)
        }
        return ctx
    }
}
