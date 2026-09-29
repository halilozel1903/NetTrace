import Foundation
import Testing
@testable import NetTrace

@Suite("Size, duration and status formatting")
struct FormattingTests {
    @Test(arguments: [
        (0, "0 B"),
        (-5, "0 B"),
        (512, "512 B"),
        (1023, "1023 B"),
        (1024, "1.0 KB"),
        (1536, "1.5 KB"),
        (20480, "20 KB"),
        (18_841, "18 KB"),
        (1_572_864, "1.5 MB"),
        (3_221_225_472, "3.0 GB"),
    ])
    func byteCounts(bytes: Int, expected: String) {
        #expect(NetTraceFormat.byteCount(bytes) == expected)
    }

    @Test(arguments: [
        (0.0, "0 ms"),
        (0.084, "84 ms"),
        (0.9994, "999 ms"),
        (0.9996, "1.00 s"),
        (1.5, "1.50 s"),
        (59.0, "59.00 s"),
        (65.0, "1m 05s"),
        (754.0, "12m 34s"),
        (-3.0, "0 ms"),
    ])
    func durations(seconds: Double, expected: String) {
        #expect(NetTraceFormat.duration(seconds) == expected)
    }

    @Test func reasonPhrases() {
        #expect(HTTPStatus.reasonPhrase(for: 200) == "OK")
        #expect(HTTPStatus.reasonPhrase(for: 404) == "Not Found")
        #expect(HTTPStatus.reasonPhrase(for: 500) == "Internal Server Error")
        #expect(HTTPStatus.reasonPhrase(for: 299) == "Success")
        #expect(HTTPStatus.reasonPhrase(for: 499) == "Client Error")
        #expect(HTTPStatus.reasonPhrase(for: 999) == "Unknown")
        #expect(NetTraceFormat.status(201) == "201 Created")
    }
}
