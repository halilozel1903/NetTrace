import Foundation
import Testing
@testable import NetTrace

@Suite("cURL export")
struct CURLBuilderTests {
    let url = URL(string: "https://api.example.com/v1/users?page=2")!

    @Test func plainGETHasNoMethodFlag() {
        let command = CURLBuilder.command(method: "get", url: url, multiline: false)
        #expect(command == "curl 'https://api.example.com/v1/users?page=2'")
    }

    @Test func postWithHeadersAndJSONBody() {
        let command = CURLBuilder.command(
            method: "POST",
            url: URL(string: "https://api.example.com/v1/users")!,
            headers: ["Content-Type": "application/json", "Accept": "*/*"],
            body: Data(#"{"name":"Ada"}"#.utf8),
            multiline: false
        )
        #expect(command == #"curl -X POST 'https://api.example.com/v1/users' -H 'Accept: */*' -H 'Content-Type: application/json' --data-raw '{"name":"Ada"}'"#)
    }

    @Test func multilineJoinsWithBackslashes() {
        let command = CURLBuilder.command(method: "DELETE", url: url, headers: ["X-Trace": "1"])
        #expect(command == "curl \\\n  -X DELETE \\\n  'https://api.example.com/v1/users?page=2' \\\n  -H 'X-Trace: 1'")
    }

    @Test func singleQuotesAreEscaped() {
        #expect(CURLBuilder.shellQuoted("it's") == #"'it'\''s'"#)
        let command = CURLBuilder.command(method: "POST", url: url, body: Data("it's".utf8), multiline: false)
        #expect(command.hasSuffix(#"--data-raw 'it'\''s'"#))
    }

    @Test func headIsHeadAndGETWithBodyIsExplicit() {
        #expect(CURLBuilder.command(method: "HEAD", url: url, multiline: false) == "curl --head 'https://api.example.com/v1/users?page=2'")
        let get = CURLBuilder.command(method: "GET", url: url, body: Data("q".utf8), multiline: false)
        #expect(get.hasPrefix("curl -X GET "))
    }

    @Test func contentLengthIsSkipped() {
        let command = CURLBuilder.command(method: "POST", url: url, headers: ["Content-Length": "12", "content-type": "text/plain"], multiline: false)
        #expect(!command.contains("Content-Length"))
        #expect(command.contains("-H 'content-type: text/plain'"))
    }

    @Test func recordWithTruncatedBodyLeavesItOut() {
        let record = NetworkRecord(
            method: "PUT",
            url: url,
            requestBody: Data("{\"a\":".utf8),
            requestBodySize: 4096
        )
        let command = CURLBuilder.command(for: record, multiline: false)
        #expect(command.hasPrefix("# Request body (4.0 KB) was cut"))
        #expect(!command.contains("--data-raw"))
        #expect(command.hasSuffix("curl -X PUT 'https://api.example.com/v1/users?page=2'"))
    }

    @Test func recordWithBinaryBodyLeavesItOut() {
        let record = NetworkRecord(method: "POST", url: url, requestBody: Data([0xFF, 0xFE, 0x00, 0x81]))
        let command = CURLBuilder.command(for: record, multiline: false)
        #expect(command.hasPrefix("# Binary request body (4 B) is not included."))
        #expect(!command.contains("--data"))
    }

    @Test func redactedHeadersStayRedacted() {
        let record = NetworkRecord(
            url: url,
            requestHeaders: Redactor().redact(["Authorization": "Bearer secret"])
        )
        let command = CURLBuilder.command(for: record, multiline: false)
        #expect(command.contains("-H 'Authorization: [redacted]'"))
        #expect(!command.contains("secret"))
    }
}
