import Foundation

public final class CoreApiManagerAsync: @unchecked Sendable {
    private let session: URLSession
    private let pipeline: RequestPipeline
    private let retryPolicy: RetryPolicy

    public init(
        session: URLSession = .shared,
        pipeline: RequestPipeline = .init(interceptors: []),
        retryPolicy: RetryPolicy = .init()
    ) {
        self.session = session
        self.pipeline = pipeline
        self.retryPolicy = retryPolicy
    }

    public func request(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let prepared = try await pipeline.run(request)
        var attempt = 0

        while true {
            try Task.checkCancellation()
            attempt += 1

            do {
                let (data, response) = try await session.data(for: prepared)
                guard let http = response as? HTTPURLResponse else {
                    throw NetworkError.invalidResponse
                }

                if (200...299).contains(http.statusCode) {
                    return (data, http)
                }

                if attempt <= retryPolicy.maxRetries, retryPolicy.shouldRetry(statusCode: http.statusCode) {
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
