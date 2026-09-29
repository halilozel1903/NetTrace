import Foundation

/// Builds a `curl` command that repeats a request in the terminal.
public enum CURLBuilder {
    /// Headers curl computes itself; copying them can only make the command wrong.
    static let skippedHeaders: Set<String> = ["content-length"]

    /// A curl command for `record`. Redacted headers stay redacted.
    /// A body that was cut or is not text is left out, with a comment saying so.
    public static func command(for record: NetworkRecord, multiline: Bool = true) -> String {
        var notes: [String] = []
        var body = record.requestBody
        if record.isRequestBodyTruncated {
            notes.append("# Request body (\(NetTraceFormat.byteCount(record.requestBodySize))) was cut when captured and is not included.")
            body = nil
        } else if let data = body, !data.isEmpty, String(data: data, encoding: .utf8) == nil {
            notes.append("# Binary request body (\(NetTraceFormat.byteCount(data.count))) is not included.")
            body = nil
        }
        let curl = command(method: record.method, url: record.url, headers: record.requestHeaders, body: body, multiline: multiline)
        return (notes + [curl]).joined(separator: "\n")
    }

    /// A curl command. Headers are sorted by name so the output is stable.
    ///
    /// ```
    /// curl -X POST 'https://api.example.com/users' \
    ///   -H 'Content-Type: application/json' \
    ///   --data-raw '{"name":"Ada"}'
    /// ```
    public static func command(method: String, url: URL, headers: [String: String] = [:], body: Data? = nil, multiline: Bool = true) -> String {
        var parts = ["curl"]
        let method = method.uppercased()
        let text = body.flatMap { $0.isEmpty ? nil : String(data: $0, encoding: .utf8) }

        switch method {
        case "HEAD":
            parts.append("--head")
        case "GET":
            if text != nil { parts.append("-X GET") }
        default:
            parts.append("-X \(method)")
        }

        parts.append(shellQuoted(url.absoluteString))

        let sortedHeaders = headers
            .filter { !skippedHeaders.contains($0.key.lowercased()) }
            .sorted { $0.key.lowercased() < $1.key.lowercased() }
        for (name, value) in sortedHeaders {
            parts.append("-H " + shellQuoted("\(name): \(value)"))
        }

        if let text {
            parts.append("--data-raw " + shellQuoted(text))
        }

        return parts.joined(separator: multiline ? " \\\n  " : " ")
    }

    /// Wraps `value` in single quotes for POSIX shells.
    public static func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
    }
}
