import Foundation

public final class CoreApiManagerAsync: @unchecked Sendable {
    private let session: URLSession
    private let pipeline: RequestPipeline
    private let retryPolicy: RetryPolicy
    private let authTokenActor: AuthTokenActor?

    public init(
        session: URLSession = .shared,
        pipeline: RequestPipeline = .init(interceptors: []),
        retryPolicy: RetryPolicy = .init(),
        authTokenActor: AuthTokenActor? = nil
    ) {
        self.session = session
        self.pipeline = pipeline
        self.retryPolicy = retryPolicy
        self.authTokenActor = authTokenActor
    }

    public func request(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        var attempt = 0
        var didUnauthorizedRetry = false

        while true {
            try Task.checkCancellation()
            attempt += 1

            // Always re-run pipeline so headers update after token refresh
            let prepared = try await pipeline.run(request)
            let authHeader = prepared.value(forHTTPHeaderField: "Authorization")
            let tokenUsed: String? = {
                guard let h = authHeader else { return nil }
                if h.hasPrefix("Bearer ") { return String(h.dropFirst("Bearer ".count)) }
                return nil
            }()

            // Capture which auth header was actually sent for THIS attempt

            do {
                let (data, response) = try await session.data(for: prepared)

                guard let http = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }

                if (200...299).contains(http.statusCode) {
                    return (data, http)
                }

                // 401 handling: refresh only if this request used the CURRENT token
                // (or used NO token at all). If token already rotated, just retry.
                if http.statusCode == 401, let authTokenActor, didUnauthorizedRetry == false {
                    didUnauthorizedRetry = true
                    _ = try await authTokenActor.refreshIfNeededAfterUnauthorized(tokenUsed: tokenUsed)
                    continue
                }

                // Retry transient failures
                if attempt <= retryPolicy.maxRetries,
                   retryPolicy.shouldRetry(statusCode: http.statusCode)
                {
                    try await Task.sleep(nanoseconds: retryPolicy.delay(forAttempt: attempt))
                    continue
                }

                let preview = String(data: data.prefix(256), encoding: .utf8)
                throw NetworkError.httpStatus(code: http.statusCode, bodyPreview: preview)

            } catch is CancellationError {
                throw NetworkError.cancelled
            } catch let e as URLError {
                throw NetworkError.transport(e)
            }
        }
    }
}
