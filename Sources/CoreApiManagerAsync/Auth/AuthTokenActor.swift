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

    /// Returns a valid token; if a refresh is already in-flight, callers will await the same Task.
    public func validToken() async throws -> String {
        if let token { return token }

        if let refreshTask {
            return try await refreshTask.value
        }

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

    /// Used when we get a 401. Forces token invalidation and triggers (single-flight) refresh.
    public func invalidateAndRefresh() async throws -> String {
        token = nil
        return try await validToken()
    }
}
