import Foundation

/// Replaces the values of sensitive headers before a request is stored.
public struct Redactor: Sendable, Equatable {
    /// `Authorization`, `Proxy-Authorization`, `Cookie` and `Set-Cookie`.
    public static let defaultHeaders: Set<String> = ["Authorization", "Proxy-Authorization", "Cookie", "Set-Cookie"]

    /// What a redacted value looks like.
    public static let placeholder = "[redacted]"

    /// Keeps every header as it is.
    public static let none = Redactor(headers: [])

    /// The lowercased names to redact.
    public let headerNames: Set<String>

    public init(headers: Set<String> = Redactor.defaultHeaders) {
        headerNames = Set(headers.map { $0.lowercased() })
    }

    public func shouldRedact(_ name: String) -> Bool {
        headerNames.contains(name.lowercased())
    }

    /// `headers` with every sensitive value replaced by ``placeholder``. Names keep their case.
    public func redact(_ headers: [String: String]) -> [String: String] {
        guard !headerNames.isEmpty else { return headers }
        var result = headers
        for name in headers.keys where shouldRedact(name) {
            result[name] = Self.placeholder
        }
        return result
    }
}
