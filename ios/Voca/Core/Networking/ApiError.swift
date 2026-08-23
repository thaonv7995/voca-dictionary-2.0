import Foundation

/// A typed API failure carrying the backend's HTTP status, machine `code` and human `message`.
/// Mirrors the web client's `ApiError` (`web/src/lib/api.ts`).
struct ApiError: LocalizedError, Equatable {
    let status: Int
    let code: String
    let message: String

    var errorDescription: String? { message }

    static let sessionExpired = ApiError(
        status: 401, code: "UNAUTHORIZED", message: "Phiên đăng nhập đã hết hạn.")

    static let badResponse = ApiError(
        status: 0, code: "BAD_RESPONSE", message: "Phản hồi không hợp lệ từ máy chủ.")

    static func network(_ underlying: Error) -> ApiError {
        ApiError(status: 0, code: "NETWORK",
                 message: "Không kết nối được máy chủ. \(underlying.localizedDescription)")
    }
}
