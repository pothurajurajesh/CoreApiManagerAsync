import XCTest
@testable import CoreApiManagerAsync

final class CoreApiManagerAsyncTests: XCTestCase {

    override func tearDown() {
        MockURLProtocol.handler = nil
        super.tearDown()
    }

    func test500ParallelRequestsTriggersSingleRefresh() async throws {
        let url = URL(string: "https://example.com/test")!

        // URLSession wired to MockURLProtocol
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)

        // Mock server behavior:
        // - If Authorization == Bearer valid => 200
        // - Otherwise => 401
        MockURLProtocol.handler = { request in
            let auth = request.value(forHTTPHeaderField: "Authorization") ?? ""
            if auth == "Bearer valid" {
                let resp = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: nil)!
                return (resp, Data("ok".utf8))
            } else {
                let resp = HTTPURLResponse(url: url, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }
        }

        let refresher = MockRefresher()
        let tokenActor = AuthTokenActor(initialToken: "expired", refresher: refresher)

        let pipeline = RequestPipeline(interceptors: [
            AuthHeaderInterceptor(tokenActor: tokenActor)
        ])

        let api = CoreApiManagerAsync(
            session: session,
            pipeline: pipeline,
            retryPolicy: RetryPolicy(maxRetries: 0, baseDelaySeconds: 0),
            authTokenActor: tokenActor
        )

        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<500 {
                group.addTask {
                    let request = URLRequest(url: url) // new per task (important for CI stability)
                    let (data, http) = try await api.request(request)
                    XCTAssertEqual(http.statusCode, 200)
                    XCTAssertEqual(String(data: data, encoding: .utf8), "ok")
                }
            }
            try await group.waitForAll()
        }

        let count = await refresher.count()
        XCTAssertEqual(count, 1, "Expected exactly 1 token refresh under concurrency")
    }
}

actor MockRefresher: AuthTokenRefreshing {
    private var refreshCount = 0

    func refreshToken() async throws -> String {
        refreshCount += 1
        return "valid"
    }

    func count() -> Int { refreshCount }
}
