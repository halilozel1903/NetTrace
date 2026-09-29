import Foundation

/// Locale-independent formatting for sizes and durations, so the list reads the same everywhere.
public enum NetTraceFormat {
    /// `512 B`, `1.5 KB`, `18 KB`, `2.4 MB`. Uses 1024-byte units.
    public static func byteCount(_ bytes: Int) -> String {
        guard bytes >= 1024 else { return "\(max(0, bytes)) B" }
        var value = Double(bytes)
        var unit = "B"
        for next in ["KB", "MB", "GB", "TB"] {
            value /= 1024
            unit = next
            if value < 1024 { break }
        }
        if value < 10 {
            return String(format: "%.1f", value) + " " + unit
        }
        return "\(Int(value.rounded())) \(unit)"
    }

    /// `84 ms`, `1.24 s`, `2m 05s`.
    public static func duration(_ seconds: TimeInterval) -> String {
        let seconds = max(0, seconds)
        let milliseconds = Int((seconds * 1000).rounded())
        if milliseconds < 1000 {
            return "\(milliseconds) ms"
        }
        if seconds < 60 {
            return String(format: "%.2f s", seconds)
        }
        let whole = Int(seconds.rounded())
        let remainder = whole % 60
        return "\(whole / 60)m " + (remainder < 10 ? "0" : "") + "\(remainder)s"
    }

    /// A status code with its reason phrase: `404 Not Found`.
    public static func status(_ code: Int) -> String {
        "\(code) \(HTTPStatus.reasonPhrase(for: code))"
    }
}
