import Foundation

public enum NetworkError: Error, Equatable {
    case invalidResponse
    case httpStatus(code: Int, bodyPreview: String?)
    case decodingFailed
    case cancelled
    case transport(URLError)
    case unknown(String)
}
