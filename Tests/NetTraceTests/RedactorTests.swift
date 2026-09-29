import Foundation
import Testing
@testable import NetTrace

@Suite("Header redaction")
struct RedactorTests {
    @Test func defaultsCoverCredentialsAndCookies() {
        let redactor = Redactor()
        let headers = [
            "Authorization": "Bearer abc",
            "cookie": "session=1",
            "Set-Cookie": "id=2",
            "Proxy-Authorization": "Basic xyz",
            "Accept": "application/json",
        ]
        let redacted = redactor.redact(headers)
        #expect(redacted["Authorization"] == Redactor.placeholder)
        #expect(redacted["cookie"] == Redactor.placeholder)
        #expect(redacted["Set-Cookie"] == Redactor.placeholder)
        #expect(redacted["Proxy-Authorization"] == Redactor.placeholder)
        #expect(redacted["Accept"] == "application/json")
        #expect(redacted.count == headers.count)
    }

    @Test func matchingIsCaseInsensitive() {
        let redactor = Redactor(headers: ["X-API-Key"])
        #expect(redactor.shouldRedact("x-api-key"))
        #expect(redactor.shouldRedact("X-Api-Key"))
        #expect(!redactor.shouldRedact("Authorization"))
        #expect(redactor.redact(["x-api-key": "k"]) == ["x-api-key": Redactor.placeholder])
    }

    @Test func noneKeepsEverything() {
        let headers = ["Authorization": "Bearer abc"]
        #expect(Redactor.none.redact(headers) == headers)
    }

    @Test func capturedRequestIsRedactedBeforeStoring() {
        var request = URLRequest(url: URL(string: "https://api.example.com/me")!)
        request.setValue("Bearer secret", forHTTPHeaderField: "Authorization")
        request.setValue("en", forHTTPHeaderField: "Accept-Language")
        let record = NetworkRecord(request: request, body: nil, maxBodySize: 100, redactor: Redactor(), startDate: Date())
        #expect(record.requestHeaders["Authorization"] == Redactor.placeholder)
        #expect(record.requestHeaders["Accept-Language"] == "en")
    }

    @Test func responseHeadersAreRedactedToo() {
        let url = URL(string: "https://api.example.com/login")!
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: [
            "Set-Cookie": "session=abc",
            "Content-Type": "application/json",
        ])
        var record = NetworkRecord(method: "POST", url: url)
        record.complete(response: response, body: BodyBuffer(limit: 10), error: nil, redactor: Redactor(), at: Date())
        #expect(NetworkRecord.header("set-cookie", in: record.responseHeaders) == Redactor.placeholder)
        #expect(record.responseContentType == "application/json")
    }
}
