import Foundation
import Testing
@testable import NetTrace

@Suite("JSON formatting")
struct JSONFormatterTests {
    @Test func prettyPrintsWithTwoSpacesKeepingKeyOrder() {
        let data = Data(#"{"b":1,"a":[true,null,"x"],"e":{},"f":[]}"#.utf8)
        let expected = """
        {
          "b": 1,
          "a": [
            true,
            null,
            "x"
          ],
          "e": {},
          "f": []
        }
        """
        #expect(JSONFormatter.prettyPrinted(data) == expected)
    }

    @Test func numbersKeepTheirSpelling() {
        let pretty = JSONFormatter.prettyPrinted(Data(#"{"price":19.90,"big":1e10,"neg":-0.5}"#.utf8))
        #expect(pretty?.contains(#""price": 19.90"#) == true)
        #expect(pretty?.contains(#""big": 1e10"#) == true)
        #expect(pretty?.contains(#""neg": -0.5"#) == true)
    }

    @Test func escapedQuotesAndBracesInStringsAreKept() {
        let pretty = JSONFormatter.prettyPrinted(Data(#"{"q":"say \"hi\" {ok}, [x]"}"#.utf8))
        #expect(pretty == "{\n  \"q\": \"say \\\"hi\\\" {ok}, [x]\"\n}")
    }

    @Test func reformattingIsStable() {
        let data = Data(#"  { "a" : [ 1 , 2 ] }  "#.utf8)
        let once = JSONFormatter.prettyPrinted(data)
        let twice = once.flatMap { JSONFormatter.prettyPrinted(Data($0.utf8)) }
        #expect(once != nil)
        #expect(once == twice)
    }

    @Test func invalidOrEmptyIsNotJSON() {
        #expect(JSONFormatter.prettyPrinted(Data("hello".utf8)) == nil)
        #expect(JSONFormatter.prettyPrinted(Data("{\"a\":".utf8)) == nil)
        #expect(JSONFormatter.prettyPrinted(Data()) == nil)
        #expect(!JSONFormatter.isJSON(Data([0xFF, 0x00])))
        #expect(JSONFormatter.isJSON(Data("42".utf8)))
    }

    @Test func tokenizerMarksKeysAndRoundTrips() {
        let text = #"{"id": 7, "ok": false, "name": "x:y"}"#
        let tokens = JSONFormatter.tokenize(text)
        #expect(tokens.map(\.text).joined() == text)
        #expect(tokens.filter { $0.kind == .key }.map(\.text) == [#""id""#, #""ok""#, #""name""#])
        #expect(tokens.filter { $0.kind == .string }.map(\.text) == [#""x:y""#])
        #expect(tokens.filter { $0.kind == .number }.map(\.text) == ["7"])
        #expect(tokens.filter { $0.kind == .literal }.map(\.text) == ["false"])
    }

    @Test func unterminatedStringDoesNotCrash() {
        let tokens = JSONFormatter.tokenize(#"{"open"#)
        #expect(tokens.last == JSONToken(.string, #""open"#))
    }
}
