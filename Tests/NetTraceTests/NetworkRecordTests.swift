import Foundation
import Testing
@testable import NetTrace

@Suite("Records, status categories and body capture")
struct NetworkRecordTests {
    let start = Date(timeIntervalSince1970: 1_800_000_000)

    @Test func statusCategories() {
        func category(_ code: Int?, error: Bool = false, complete: Bool = true) -> StatusCategory {
            StatusCategory(statusCode: code, hasError: error, isComplete: complete)
        }
        #expect(category(nil, complete: false) == .pending)
        #expect(category(nil) == .failed)
        #expect(category(nil, error: true) == .failed)
        #expect(category(101) == .success)
        #expect(category(200) == .success)
        #expect(category(204) == .success)
        #expect(category(304) == .redirect)
        #expect(category(404) == .clientError)
        #expect(category(503) == .serverError)
        #expect(category(200, error: true) == .failed)
        #expect(category(700) == .failed)
    }

    @Test func durationAndCompletion() {
        let running = NetworkRecord(url: URL(string: "https://example.com")!, startDate: start)
        #expect(!running.isComplete)
        #expect(running.duration == nil)
        #expect(running.category == .pending)

        let done = NetworkRecord(url: URL(string: "https://example.com")!, startDate: start, endDate: start.addingTimeInterval(0.25), statusCode: 200)
        #expect(done.duration == 0.25)
        #expect(done.category == .success)
    }

    @Test func pathAndQueryAndHost() {
        let record = NetworkRecord(url: URL(string: "https://api.example.com/v2/search?q=red%20shoes&page=1")!)
        #expect(record.host == "api.example.com")
        #expect(record.pathAndQuery == "/v2/search?q=red shoes&page=1")
        #expect(record.queryItems.map(\.name) == ["q", "page"])
        #expect(NetworkRecord(url: URL(string: "https://example.com")!).pathAndQuery == "/")
    }

    @Test func headerLookupIsCaseInsensitive() {
        let record = NetworkRecord(url: URL(string: "https://example.com")!, requestHeaders: ["content-type": "text/plain"])
        #expect(record.requestContentType == "text/plain")
        #expect(NetworkRecord.header("CONTENT-TYPE", in: ["Content-Type": "a"]) == "a")
        #expect(NetworkRecord.header("Accept", in: [:]) == nil)
    }

    @Test func methodIsUppercasedAndSizesDefaultToBodyCount() {
        let record = NetworkRecord(method: "patch", url: URL(string: "https://example.com")!, requestBody: Data("abc".utf8))
        #expect(record.method == "PATCH")
        #expect(record.requestBodySize == 3)
        #expect(!record.isRequestBodyTruncated)
        #expect(record.responseBodySize == 0)
    }

    @Test func capturedRequestBodyIsCut() {
        var request = URLRequest(url: URL(string: "https://example.com/upload")!)
        request.httpMethod = "POST"
        let body = Data(repeating: 7, count: 100)
        let record = NetworkRecord(request: request, body: body, maxBodySize: 10, redactor: .none, startDate: start)
        #expect(record.requestBody?.count == 10)
        #expect(record.requestBodySize == 100)
        #expect(record.isRequestBodyTruncated)
        #expect(record.method == "POST")
    }

    @Test func completeFillsInResponseAndError() {
        let url = URL(string: "https://example.com/data")!
        var buffer = BodyBuffer(limit: 4)
        buffer.append(Data("hello world".utf8))
        let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: ["X-Id": "9"])

        var record = NetworkRecord(url: url, startDate: start)
        record.complete(response: response, body: buffer, error: nil, redactor: Redactor(), at: start.addingTimeInterval(1))
        #expect(record.statusCode == 404)
        #expect(NetworkRecord.header("x-id", in: record.responseHeaders) == "9")
        #expect(record.responseBody == Data("hell".utf8))
        #expect(record.responseBodySize == 11)
        #expect(record.isResponseBodyTruncated)
        #expect(record.category == .clientError)

        var failed = NetworkRecord(url: url, startDate: start)
        failed.complete(response: nil, body: BodyBuffer(limit: 4), error: URLError(.cancelled), redactor: Redactor(), at: start)
        #expect(failed.errorDescription == "Cancelled")
        #expect(failed.responseBody == nil)
        #expect(failed.category == .failed)
    }

    @Test func bodyBufferKeepsCountingPastTheLimit() {
        var buffer = BodyBuffer(limit: 5)
        buffer.append(Data("abc".utf8))
        buffer.append(Data("defg".utf8))
        buffer.append(Data("hij".utf8))
        #expect(buffer.data == Data("abcde".utf8))
        #expect(buffer.totalBytes == 10)
        #expect(buffer.isTruncated)

        var unlimited = BodyBuffer(limit: 100)
        unlimited.append(Data("abc".utf8))
        #expect(!unlimited.isTruncated)
        #expect(BodyBuffer(limit: -1).limit == 0)
    }
}
