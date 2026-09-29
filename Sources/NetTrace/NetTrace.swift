import Foundation

/// The entry point of NetTrace.
///
/// Call ``enable(options:registerGlobally:)`` once at launch, in debug builds only:
///
/// ```swift
/// #if DEBUG
/// NetTrace.enable()
/// #endif
/// ```
///
/// That records every request made through `URLSession.shared`. Sessions you create
/// yourself need the protocol in their configuration:
///
/// ```swift
/// let session = URLSession(configuration: NetTrace.configuration())
/// ```
public enum NetTrace {
    /// The store every captured request goes into. The inspector UI reads from it by default.
    public static let store = NetTraceStore()

    private struct State {
        var isEnabled = false
        var isRegistered = false
        var options = NetTraceOptions()
    }

    private static let state = Locked(State())

    /// Whether requests are currently recorded.
    public static var isEnabled: Bool {
        state.withLock { $0.isEnabled }
    }

    /// Body size cap, redacted headers, ignored hosts and history length.
    /// Changes apply to requests that start afterwards.
    public static var options: NetTraceOptions {
        get { state.withLock { $0.options } }
        set {
            state.withLock { $0.options = newValue }
            store.maxRecords = newValue.maxRecords
        }
    }

    /// Starts recording.
    ///
    /// - Parameters:
    ///   - options: Replaces ``options`` when given.
    ///   - registerGlobally: Registers ``NetTraceURLProtocol`` with `URLProtocol.registerClass(_:)`,
    ///     which covers `URLSession.shared`. Pass `false` to record only the sessions whose
    ///     configuration went through ``configuration(_:)`` or ``inject(into:)``.
    public static func enable(options: NetTraceOptions? = nil, registerGlobally: Bool = true) {
        if let options {
            self.options = options
        }
        let needsRegistration = state.withLock { (state: inout State) -> Bool in
            state.isEnabled = true
            guard registerGlobally, !state.isRegistered else { return false }
            state.isRegistered = true
            return true
        }
        if needsRegistration {
            URLProtocol.registerClass(NetTraceURLProtocol.self)
        }
    }

    /// Stops recording. Requests already in the store stay there.
    public static func disable() {
        state.withLock { $0.isEnabled = false }
    }

    /// Removes every recorded request.
    public static func clear() {
        store.clear()
    }

    /// Returns `base` with ``NetTraceURLProtocol`` in front of its protocol classes.
    ///
    /// ```swift
    /// let session = URLSession(configuration: NetTrace.configuration(.ephemeral))
    /// ```
    public static func configuration(_ base: URLSessionConfiguration = .default) -> URLSessionConfiguration {
        inject(into: base)
        return base
    }

    /// Puts ``NetTraceURLProtocol`` in front of the configuration's protocol classes (once).
    public static func inject(into configuration: URLSessionConfiguration) {
        var classes = configuration.protocolClasses ?? []
        let traceID = ObjectIdentifier(NetTraceURLProtocol.self)
        guard !classes.contains(where: { ObjectIdentifier($0) == traceID }) else { return }
        classes.insert(NetTraceURLProtocol.self, at: 0)
        configuration.protocolClasses = classes
    }
}

/// What NetTrace records and keeps.
public struct NetTraceOptions: Sendable, Equatable {
    /// Bodies larger than this are cut; the full size is still shown. Default 256 KB.
    public var maxBodySize: Int
    /// Header names (case-insensitive) whose values are replaced before anything is stored.
    public var redactedHeaders: Set<String>
    /// Hosts that are never recorded, for example your analytics endpoint. Subdomains match too.
    public var ignoredHosts: Set<String>
    /// How many requests the store keeps. The oldest ones are dropped first. Default 500.
    public var maxRecords: Int

    public init(
        maxBodySize: Int = 256 * 1024,
        redactedHeaders: Set<String> = Redactor.defaultHeaders,
        ignoredHosts: Set<String> = [],
        maxRecords: Int = 500
    ) {
        self.maxBodySize = max(0, maxBodySize)
        self.redactedHeaders = redactedHeaders
        self.ignoredHosts = ignoredHosts
        self.maxRecords = max(1, maxRecords)
    }

    /// The redactor for ``redactedHeaders``.
    public var redactor: Redactor {
        Redactor(headers: redactedHeaders)
    }

    /// Whether requests to `host` are skipped. `example.com` also matches `api.example.com`.
    public func ignoresHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased(), !host.isEmpty else { return false }
        return ignoredHosts.contains { ignored in
            let ignored = ignored.lowercased()
            return host == ignored || host.hasSuffix("." + ignored)
        }
    }
}

/// A value guarded by a lock. Works on iOS 17 (where `Mutex` is not available yet).
final class Locked<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    func withLock<R>(_ body: (inout Value) throws -> R) rethrows -> R {
        lock.lock()
        defer { lock.unlock() }
        return try body(&value)
    }
}
