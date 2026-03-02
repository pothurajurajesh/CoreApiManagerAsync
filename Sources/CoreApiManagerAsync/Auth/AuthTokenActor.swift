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

    /// Call this only when we get a 401.
    public func refreshIfNeededAfterUnauthorized() async throws -> String {
        // If refresh already running, join it
        if let task = refreshTask {
            return try await task.value
        }

        // Start a single refresh task
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
