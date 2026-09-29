import Foundation

/// Records HTTP and HTTPS requests into ``NetTrace/store`` and forwards them to the network.
///
/// You rarely use this class directly: ``NetTrace/enable(options:registerGlobally:)`` registers it
/// and ``NetTrace/configuration(_:)`` adds it to a session configuration.
public final class NetTraceURLProtocol: URLProtocol, @unchecked Sendable {
    /// Marks requests this protocol already forwarded, so they are not recorded twice.
    static let handledKey = "io.github.halilozel1903.NetTrace.handled"

    /// All mutable state, guarded by a lock: URLSession calls the delegate on its own queue
    /// while the loading system calls `startLoading` / `stopLoading` on another thread.
    private struct State {
        var session: URLSession?
        var task: URLSessionDataTask?
        var recordID: UUID?
        var buffer = BodyBuffer(limit: 0)
        var redactor = Redactor()
        var didSendResponse = false
        var isStopped = false
    }

    private let state = Locked(State())

    // MARK: URLProtocol

    override public class func canInit(with request: URLRequest) -> Bool {
        guard NetTrace.isEnabled,
              let url = request.url,
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              URLProtocol.property(forKey: handledKey, in: request) == nil
        else {
            return false
        }
        return !NetTrace.options.ignoresHost(url.host())
    }

    override public class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override public func startLoading() {
        let options = NetTrace.options
        let original = request
        let body = Self.readBody(of: original)

        var forwarded = original
        if let body {
            // URLSession often turns `httpBody` into a stream on the way here. The stream
            // was read above, so the forwarded request carries the bytes directly.
            forwarded.httpBody = body
        }
        guard let mutable = (forwarded as NSURLRequest).mutableCopy() as? NSMutableURLRequest else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        URLProtocol.setProperty(true, forKey: Self.handledKey, in: mutable)
        let tagged = mutable as URLRequest

        let redactor = options.redactor
        let record = NetworkRecord(
            request: original,
            body: body,
            maxBodySize: options.maxBodySize,
            redactor: redactor,
            startDate: Date()
        )
        NetTrace.store.insert(record)

        let configuration = URLSessionConfiguration.default
        let traceID = ObjectIdentifier(NetTraceURLProtocol.self)
        configuration.protocolClasses = configuration.protocolClasses?.filter { ObjectIdentifier($0) != traceID }
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
        let task = session.dataTask(with: tagged)

        state.withLock { state in
            state.session = session
            state.task = task
            state.recordID = record.id
            state.buffer = BodyBuffer(limit: options.maxBodySize)
            state.redactor = redactor
        }
        task.resume()
    }

    override public func stopLoading() {
        let (task, session) = state.withLock { (state: inout State) -> (URLSessionDataTask?, URLSession?) in
            state.isStopped = true
            return (state.task, state.session)
        }
        task?.cancel()
        // Breaks the session -> delegate reference once the task is done.
        session?.finishTasksAndInvalidate()
    }

    // MARK: Helpers

    /// The request body, read from `httpBodyStream` when `httpBody` is empty.
    static func readBody(of request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return nil
        }
        stream.open()
        defer { stream.close() }

        let chunkSize = 16 * 1024
        var buffer = [UInt8](repeating: 0, count: chunkSize)
        var data = Data()
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: chunkSize)
            if count <= 0 { break }
            data.append(contentsOf: buffer[0..<count])
        }
        return data
    }
}

// MARK: - URLSessionDataDelegate

// Only these two callbacks are implemented. Redirects, authentication challenges and the
// response disposition keep URLSession's default behavior.
extension NetTraceURLProtocol: URLSessionDataDelegate {
    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        let (response, isStopped) = state.withLock { (state: inout State) -> (URLResponse?, Bool) in
            state.buffer.append(data)
            if state.didSendResponse {
                return (nil, state.isStopped)
            }
            state.didSendResponse = true
            return (dataTask.response, state.isStopped)
        }
        guard !isStopped else { return }
        if let response {
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        }
        client?.urlProtocol(self, didLoad: data)
    }

    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: (any Error)?) {
        let response = task.response
        let (pendingResponse, buffer, recordID, redactor, isStopped) = state.withLock {
            (state: inout State) -> (URLResponse?, BodyBuffer, UUID?, Redactor, Bool) in
            let pending = state.didSendResponse ? nil : response
            state.didSendResponse = true
            return (pending, state.buffer, state.recordID, state.redactor, state.isStopped)
        }

        if let recordID {
            let finished = Date()
            NetTrace.store.update(id: recordID) { record in
                record.complete(response: response, body: buffer, error: error, redactor: redactor, at: finished)
            }
        }

        guard !isStopped else { return }
        if let pendingResponse {
            client?.urlProtocol(self, didReceive: pendingResponse, cacheStoragePolicy: .notAllowed)
        }
        if let error {
            client?.urlProtocol(self, didFailWithError: error)
        } else {
            client?.urlProtocolDidFinishLoading(self)
        }
    }
}
