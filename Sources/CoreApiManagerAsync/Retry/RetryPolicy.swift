import Foundation

public struct RetryPolicy: Sendable {
    public let maxRetries: Int
    public let baseDelaySeconds: Double

    public init(maxRetries: Int = 2, baseDelaySeconds: Double = 0.3) {
        self.maxRetries = maxRetries
        self.baseDelaySeconds = baseDelaySeconds
    }

    public func delay(forAttempt attempt: Int) -> UInt64 {
        // Exponential backoff: base * 2^(attempt-1)
        let seconds = baseDelaySeconds * pow(2.0, Double(max(0, attempt - 1)))
        return UInt64(seconds * 1_000_000_000)
    }

    public func shouldRetry(statusCode: Int) -> Bool {
        // Typical transient failures
        return statusCode == 408 || statusCode == 429 || (500...599).contains(statusCode)
    }
}
