import Foundation

public protocol AuthTokenRefreshing: Sendable {
    func refreshToken() async throws -> String
}

public actor AuthTokenActor {
    private var token: String?
    private var refreshTask: Task<String, Error>?
    private let refresher: AuthTokenRefreshing

    public init(initialToken: String? = nil, refresher: AuthTokenRefreshing) {
        self.token = initialToken
        self.refresher = refresher
    }

    public func currentToken() -> String? { token }

    /// Call this only when we get a 401.
    /// Refresh ONLY if the failing request used the current token (as an auth header).
    public func refreshIfNeededAfterUnauthorized(authHeaderUsed: String?) async throws -> String {
        let currentHeader = token.map { "Bearer \($0)" }

        // If token already rotated since this request was sent, do not refresh again.
        if let currentHeader, let used = authHeaderUsed, used != currentHeader {
            // token changed; just return current token
            return token! // safe because currentHeader exists implies token exists
        }

        // If refresh already running, join it.
        if let task = refreshTask {
            return try await task.value
        }

        // Start a single refresh task.
        let task = Task { try await refresher.refreshToken() }
        refreshTask = task

        do {
            let newToken = try await task.value
            token = newToken
            refreshTask = nil
            return newToken
        } catch {
            refreshTask = nil
            throw error
        }
    }
}
