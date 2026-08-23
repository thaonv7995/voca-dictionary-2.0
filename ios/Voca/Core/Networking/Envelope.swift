import Foundation

/// Every JSON response under `/api/**` and `/v1/**` is wrapped in a consistent envelope:
/// `{ status, code, message, data }`. SSE streams, audio bytes and the Markdown docs are NOT
/// wrapped — those are handled separately (SSEClient / raw Data).
struct Envelope<T: Decodable>: Decodable {
    let status: Int
    let code: String
    let message: String
    let data: T
}

/// Error responses (and trivial `{ok:true}` bodies) share the same envelope shape with `data:null`.
/// Decoded when the HTTP status is non-2xx to recover the server's `code` + `message`.
struct ErrorEnvelope: Decodable {
    let status: Int
    let code: String
    let message: String
}

/// Minimal body for endpoints that just acknowledge success (e.g. logout, change-password).
struct OkResponse: Decodable {
    let ok: Bool?
}
