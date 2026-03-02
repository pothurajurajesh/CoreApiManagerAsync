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

    public func setToken(_ newToken: String?) {
        token = newToken
    }

    /// Refresh only if the failing request used the current token.
    /// If token already rotated, just return the current token (no extra refresh).
    public func refreshIfNeededAfterUnauthorized(tokenUsed: String?) async throws -> String {
        // If token already changed since this request was sent, don't refresh again.
        if let current = token, let used = tokenUsed, current != used {
            return current
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
