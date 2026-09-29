import Foundation

/// One captured request and, once it finished, its response.
public struct NetworkRecord: Identifiable, Sendable, Hashable {
    public let id: UUID
    /// The HTTP method, uppercased.
    public var method: String
    public var url: URL
    /// Request headers, already redacted.
    public var requestHeaders: [String: String]
    /// The request body, cut at the configured size.
    public var requestBody: Data?
    /// The full size of the request body in bytes.
    public var requestBodySize: Int
    public var startDate: Date
    /// When the response finished or the request failed. `nil` while it is still running.
    public var endDate: Date?
    public var statusCode: Int?
    /// Response headers, already redacted.
    public var responseHeaders: [String: String]
    /// The response body, cut at the configured size.
    public var responseBody: Data?
    /// The full size of the response body in bytes.
    public var responseBodySize: Int
    /// The error, when the request failed without a response.
    public var errorDescription: String?

    public init(
        id: UUID = UUID(),
        method: String = "GET",
        url: URL,
        requestHeaders: [String: String] = [:],
        requestBody: Data? = nil,
        requestBodySize: Int? = nil,
        startDate: Date = Date(),
        endDate: Date? = nil,
        statusCode: Int? = nil,
        responseHeaders: [String: String] = [:],
        responseBody: Data? = nil,
        responseBodySize: Int? = nil,
        errorDescription: String? = nil
    ) {
        self.id = id
        self.method = method.uppercased()
        self.url = url
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        self.requestBodySize = requestBodySize ?? requestBody?.count ?? 0
        self.startDate = startDate
        self.endDate = endDate
        self.statusCode = statusCode
        self.responseHeaders = responseHeaders
        self.responseBody = responseBody
        self.responseBodySize = responseBodySize ?? responseBody?.count ?? 0
        self.errorDescription = errorDescription
    }

    /// Whether the request finished, successfully or not.
    public var isComplete: Bool { endDate != nil }

    /// Seconds from start to finish, `nil` while running.
    public var duration: TimeInterval? {
        endDate.map { max(0, $0.timeIntervalSince(startDate)) }
    }

    public var category: StatusCategory {
        StatusCategory(statusCode: statusCode, hasError: errorDescription != nil, isComplete: isComplete)
    }

    public var isRequestBodyTruncated: Bool { (requestBody?.count ?? 0) < requestBodySize }
    public var isResponseBodyTruncated: Bool { (responseBody?.count ?? 0) < responseBodySize }

    public var host: String { url.host() ?? "" }

    /// The path and query, for example `/v2/products?page=1`.
    public var pathAndQuery: String {
        let path = url.path(percentEncoded: false)
        let base = path.isEmpty ? "/" : path
        guard let query = url.query(percentEncoded: false), !query.isEmpty else { return base }
        return base + "?" + query
    }

    public var queryItems: [URLQueryItem] {
        URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
    }

    public var requestContentType: String? { Self.header("Content-Type", in: requestHeaders) }
    public var responseContentType: String? { Self.header("Content-Type", in: responseHeaders) }

    /// Case-insensitive header lookup.
    public static func header(_ name: String, in headers: [String: String]) -> String? {
        if let exact = headers[name] { return exact }
        let lowered = name.lowercased()
        return headers.first { $0.key.lowercased() == lowered }?.value
    }
}

// MARK: - Capture

extension NetworkRecord {
    /// A running record for `request`. Headers are redacted and the body is cut here,
    /// so secrets and large payloads never reach the store.
    init(request: URLRequest, body: Data?, maxBodySize: Int, redactor: Redactor, startDate: Date, id: UUID = UUID()) {
        self.init(
            id: id,
            method: request.httpMethod ?? "GET",
            url: request.url ?? URL(string: "about:blank")!,
            requestHeaders: redactor.redact(request.allHTTPHeaderFields ?? [:]),
            requestBody: body.map { Data($0.prefix(maxBodySize)) },
            requestBodySize: body?.count ?? 0,
            startDate: startDate
        )
    }

    /// Fills in the response side.
    mutating func complete(response: URLResponse?, body: BodyBuffer, error: (any Error)?, redactor: Redactor, at date: Date) {
        endDate = date
        if let http = response as? HTTPURLResponse {
            statusCode = http.statusCode
            responseHeaders = redactor.redact(Self.stringHeaders(http.allHeaderFields))
        }
        responseBody = body.data.isEmpty ? nil : body.data
        responseBodySize = body.totalBytes
        if let error {
            errorDescription = Self.describe(error)
        }
    }

    static func stringHeaders(_ fields: [AnyHashable: Any]) -> [String: String] {
        var headers: [String: String] = [:]
        for (key, value) in fields {
            let name = (key.base as? String) ?? String(describing: key)
            headers[name] = (value as? String) ?? String(describing: value)
        }
        return headers
    }

    static func describe(_ error: any Error) -> String {
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return "Cancelled"
        }
        return (error as NSError).localizedDescription
    }
}

// MARK: - Status

/// The coarse outcome of a request, used for colors and filtering.
public enum StatusCategory: String, CaseIterable, Sendable, Hashable, Identifiable {
    case pending
    case success
    case redirect
    case clientError
    case serverError
    case failed

    public var id: String { rawValue }

    public init(statusCode: Int?, hasError: Bool, isComplete: Bool) {
        if hasError {
            self = .failed
            return
        }
        guard let statusCode else {
            self = isComplete ? .failed : .pending
            return
        }
        switch statusCode {
        case 100..<300: self = .success
        case 300..<400: self = .redirect
        case 400..<500: self = .clientError
        case 500..<600: self = .serverError
        default: self = .failed
        }
    }

    /// A short label for filter chips.
    public var title: String {
        switch self {
        case .pending: "Pending"
        case .success: "2xx"
        case .redirect: "3xx"
        case .clientError: "4xx"
        case .serverError: "5xx"
        case .failed: "Failed"
        }
    }
}

/// Reason phrases for status codes.
public enum HTTPStatus {
    private static let phrases: [Int: String] = [
        100: "Continue", 101: "Switching Protocols",
        200: "OK", 201: "Created", 202: "Accepted", 204: "No Content", 206: "Partial Content",
        301: "Moved Permanently", 302: "Found", 303: "See Other", 304: "Not Modified",
        307: "Temporary Redirect", 308: "Permanent Redirect",
        400: "Bad Request", 401: "Unauthorized", 403: "Forbidden", 404: "Not Found",
        405: "Method Not Allowed", 408: "Request Timeout", 409: "Conflict", 410: "Gone",
        413: "Content Too Large", 415: "Unsupported Media Type", 422: "Unprocessable Content",
        429: "Too Many Requests",
        500: "Internal Server Error", 501: "Not Implemented", 502: "Bad Gateway",
        503: "Service Unavailable", 504: "Gateway Timeout",
    ]

    /// `"Not Found"` for 404; a generic class name for codes without a well-known phrase.
    public static func reasonPhrase(for code: Int) -> String {
        if let phrase = phrases[code] { return phrase }
        switch code {
        case 100..<200: return "Informational"
        case 200..<300: return "Success"
        case 300..<400: return "Redirection"
        case 400..<500: return "Client Error"
        case 500..<600: return "Server Error"
        default: return "Unknown"
        }
    }
}

// MARK: - Body buffer

/// Collects a body up to a size limit while counting every byte.
public struct BodyBuffer: Sendable, Equatable {
    public let limit: Int
    public private(set) var data = Data()
    public private(set) var totalBytes = 0

    public init(limit: Int) {
        self.limit = max(0, limit)
    }

    /// Whether bytes were dropped.
    public var isTruncated: Bool { totalBytes > data.count }

    public mutating func append(_ chunk: Data) {
        totalBytes += chunk.count
        let room = limit - data.count
        guard room > 0, !chunk.isEmpty else { return }
        data.append(Data(chunk.prefix(room)))
    }
}
