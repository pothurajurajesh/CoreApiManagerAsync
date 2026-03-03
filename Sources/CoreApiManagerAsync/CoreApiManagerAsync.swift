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
        var unauthorizedRetries = 0

        while true {
            try Task.checkCancellation()
            attempt += 1

            let prepared = try await pipeline.run(request)
            let authHeaderUsed = prepared.value(forHTTPHeaderField: "Authorization")

            do {
                let (data, response) = try await session.data(for: prepared)

                guard let http = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }

                if (200...299).contains(http.statusCode) {
                    return (data, http)
                }

                // ✅ 401 handling: tolerate one extra retry after refresh (CI stability)
                if http.statusCode == 401, let authTokenActor, unauthorizedRetries < 2 {
                    unauthorizedRetries += 1
                    if unauthorizedRetries == 1 {
                        _ = try await authTokenActor.refreshIfNeededAfterUnauthorized(authHeaderUsed: authHeaderUsed)
                    }
                    continue
                }

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
