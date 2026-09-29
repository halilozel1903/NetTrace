import Foundation
import Testing
@testable import NetTrace

@Suite("Store, options and protocol helpers")
struct StoreTests {
    func record(_ path: String) -> NetworkRecord {
        NetworkRecord(url: URL(string: "https://example.com/\(path)")!)
    }

    @Test func newestFirstAndCapped() {
        let store = NetTraceStore(maxRecords: 2)
        store.insert(record("a"))
        store.insert(record("b"))
        store.insert(record("c"))
        #expect(store.records.map(\.url.lastPathComponent) == ["c", "b"])
        #expect(store.count == 2)
    }

    @Test func loweringTheCapTrims() {
        let store = NetTraceStore(records: [record("c"), record("b"), record("a")])
        store.maxRecords = 1
        #expect(store.records.map(\.url.lastPathComponent) == ["c"])
    }

    @Test func updateChangesOnlyTheMatchingRecord() {
        let store = NetTraceStore()
        let first = record("a")
        let second = record("b")
        store.insert(first)
        store.insert(second)
        store.update(id: first.id) { $0.statusCode = 204 }
        store.update(id: UUID()) { $0.statusCode = 500 }
        #expect(store.record(id: first.id)?.statusCode == 204)
        #expect(store.record(id: second.id)?.statusCode == nil)
    }

    @Test func observersSeeEveryChangeWithIncreasingVersions() {
        let store = NetTraceStore()
        let seen = Locked<[(Int, Int)]>([])
        let id = store.addObserver { version, records in
            seen.withLock { $0.append((version, records.count)) }
        }
        store.insert(record("a"))
        store.insert(record("b"))
        store.clear()
        store.removeObserver(id)
        store.insert(record("c"))

        let values = seen.withLock { $0 }
        #expect(values.map { $0.0 } == [1, 2, 3])
        #expect(values.map { $0.1 } == [1, 2, 0])
        #expect(store.snapshot().version == 4)
    }

    @Test func ignoredHostsMatchSubdomains() {
        let options = NetTraceOptions(ignoredHosts: ["analytics.example.com", "Tracker.io"])
        #expect(options.ignoresHost("analytics.example.com"))
        #expect(options.ignoresHost("eu.analytics.example.com"))
        #expect(options.ignoresHost("tracker.io"))
        #expect(!options.ignoresHost("example.com"))
        #expect(!options.ignoresHost("notanalytics.example.com"))
        #expect(!options.ignoresHost(nil))
    }

    @Test func optionsClampValues() {
        let options = NetTraceOptions(maxBodySize: -1, maxRecords: 0)
        #expect(options.maxBodySize == 0)
        #expect(options.maxRecords == 1)
        #expect(NetTraceOptions().redactor == Redactor())
    }

    @Test func injectAddsTheProtocolOnce() {
        let configuration = URLSessionConfiguration.ephemeral
        NetTrace.inject(into: configuration)
        NetTrace.inject(into: configuration)
        let classes = configuration.protocolClasses ?? []
        let traceID = ObjectIdentifier(NetTraceURLProtocol.self)
        #expect(classes.filter { ObjectIdentifier($0) == traceID }.count == 1)
        #expect(classes.first.map { ObjectIdentifier($0) } == traceID)
    }

    @Test func bodyIsReadFromTheStreamWhenNeeded() {
        var request = URLRequest(url: URL(string: "https://example.com")!)
        let payload = Data((0..<40_000).map { UInt8($0 % 251) })
        request.httpBodyStream = InputStream(data: payload)
        #expect(NetTraceURLProtocol.readBody(of: request) == payload)

        var direct = URLRequest(url: URL(string: "https://example.com")!)
        direct.httpBody = Data("x".utf8)
        #expect(NetTraceURLProtocol.readBody(of: direct) == Data("x".utf8))
        #expect(NetTraceURLProtocol.readBody(of: URLRequest(url: URL(string: "https://example.com")!)) == nil)
    }

    @Test func canInitOnlyTakesNewHTTPRequestsWhileEnabled() {
        let https = URLRequest(url: URL(string: "https://example.com/a")!)
        let websocket = URLRequest(url: URL(string: "wss://example.com/socket")!)
        let ignored = URLRequest(url: URL(string: "https://metrics.example.com/ping")!)
        let mutable = NSMutableURLRequest(url: URL(string: "https://example.com/b")!)
        URLProtocol.setProperty(true, forKey: NetTraceURLProtocol.handledKey, in: mutable)
        let handled = mutable as URLRequest

        // The only test that touches the global switch; nothing is sent over the network.
        let previous = NetTrace.options
        NetTrace.enable(options: NetTraceOptions(ignoredHosts: ["metrics.example.com"]), registerGlobally: false)
        let acceptsHTTPS = NetTraceURLProtocol.canInit(with: https)
        let acceptsWebSocket = NetTraceURLProtocol.canInit(with: websocket)
        let acceptsIgnored = NetTraceURLProtocol.canInit(with: ignored)
        let acceptsHandled = NetTraceURLProtocol.canInit(with: handled)
        NetTrace.disable()
        let acceptsWhileDisabled = NetTraceURLProtocol.canInit(with: https)
        NetTrace.options = previous

        #expect(acceptsHTTPS)
        #expect(!acceptsWebSocket)
        #expect(!acceptsIgnored)
        #expect(!acceptsHandled)
        #expect(!acceptsWhileDisabled)
    }
}
