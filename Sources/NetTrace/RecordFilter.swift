import Foundation

/// Search text plus method and status filters for the request list.
public struct RecordFilter: Sendable, Equatable {
    /// Whitespace-separated terms; every term must appear in the method, URL, status code or error.
    public var searchText: String
    /// Uppercased methods to show. Empty shows all.
    public var methods: Set<String>
    /// Status categories to show. Empty shows all.
    public var categories: Set<StatusCategory>

    public init(searchText: String = "", methods: Set<String> = [], categories: Set<StatusCategory> = []) {
        self.searchText = searchText
        self.methods = Set(methods.map { $0.uppercased() })
        self.categories = categories
    }

    public var isActive: Bool {
        !terms.isEmpty || !methods.isEmpty || !categories.isEmpty
    }

    /// The lowercased search terms.
    public var terms: [String] {
        searchText
            .split(whereSeparator: { $0.isWhitespace })
            .map { $0.lowercased() }
    }

    public func matches(_ record: NetworkRecord) -> Bool {
        if !methods.isEmpty, !methods.contains(record.method.uppercased()) {
            return false
        }
        if !categories.isEmpty, !categories.contains(record.category) {
            return false
        }
        let searchTerms = terms
        guard !searchTerms.isEmpty else { return true }
        let haystack = Self.searchableText(of: record)
        return searchTerms.allSatisfy { haystack.contains($0) }
    }

    /// The records that match, in their original order.
    public func apply(to records: [NetworkRecord]) -> [NetworkRecord] {
        guard isActive else { return records }
        return records.filter { matches($0) }
    }

    /// Adds `method` when it is not selected, removes it when it is.
    public mutating func toggle(method: String) {
        let method = method.uppercased()
        if methods.contains(method) {
            methods.remove(method)
        } else {
            methods.insert(method)
        }
    }

    public mutating func toggle(category: StatusCategory) {
        if categories.contains(category) {
            categories.remove(category)
        } else {
            categories.insert(category)
        }
    }

    /// The distinct methods in `records`, common ones first.
    public static func methods(in records: [NetworkRecord]) -> [String] {
        let order = ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]
        let found = Set(records.map { $0.method.uppercased() })
        return found.sorted { lhs, rhs in
            let left = order.firstIndex(of: lhs) ?? order.count
            let right = order.firstIndex(of: rhs) ?? order.count
            return left == right ? lhs < rhs : left < right
        }
    }

    static func searchableText(of record: NetworkRecord) -> String {
        var parts = [record.method, record.url.absoluteString]
        if let decoded = record.url.absoluteString.removingPercentEncoding {
            parts.append(decoded)
        }
        if let statusCode = record.statusCode {
            parts.append(String(statusCode))
        }
        if let error = record.errorDescription {
            parts.append(error)
        }
        return parts.joined(separator: " ").lowercased()
    }
}
