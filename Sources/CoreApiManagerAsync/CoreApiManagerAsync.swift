import Foundation

public final class CoreApiManagerAsync {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func request(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        return (data, http)
    }
}
