import Foundation

/// Builds a `mailto:` URL for the recap draft. Subject/body are percent-encoded
/// against an unreserved-only set so `&`, `=`, spaces, em-dashes and newlines all
/// survive: newlines become `%0D%0A`, the em-dash `—` becomes `%E2%80%94`.
enum MailDraft {
    private static let unreserved = CharacterSet(charactersIn:
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    static func encode(_ s: String) -> String {
        s.replacingOccurrences(of: "\r\n", with: "\n")   // normalize first
            .replacingOccurrences(of: "\n", with: "\r\n") // CRLF line breaks for mailto
            .addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
    }

    /// `to` is intentionally left empty — the user fills in the recipient.
    static func mailtoURL(subject: String, body: String, to: String = "") -> URL? {
        URL(string: "mailto:\(to)?subject=\(encode(subject))&body=\(encode(body))")
    }
}
