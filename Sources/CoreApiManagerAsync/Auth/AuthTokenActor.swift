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
}
