import Foundation

/// A piece of JSON text, used for pretty printing and syntax highlighting.
public struct JSONToken: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        /// A string followed by a colon.
        case key
        case string
        case number
        /// `true`, `false` or `null`.
        case literal
        /// `{ } [ ] : ,`
        case punctuation
        case whitespace
        /// Anything that is not valid JSON.
        case other
    }

    public var kind: Kind
    public var text: String

    public init(_ kind: Kind, _ text: String) {
        self.kind = kind
        self.text = text
    }
}

/// Pretty prints and tokenizes JSON without reordering keys or rewriting numbers.
public enum JSONFormatter {
    /// Whether `data` is a JSON document (objects, arrays and bare values all count).
    public static func isJSON(_ data: Data) -> Bool {
        guard !data.isEmpty else { return false }
        return (try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])) != nil
    }

    /// `data` indented with two spaces, or `nil` when it is not valid UTF-8 JSON.
    public static func prettyPrinted(_ data: Data) -> String? {
        guard isJSON(data), let text = String(data: data, encoding: .utf8) else { return nil }
        return format(text)
    }

    /// Re-indents JSON text. Keys keep their order and values keep their exact spelling.
    public static func format(_ text: String, indent: String = "  ") -> String {
        let tokens = tokenize(text).filter { $0.kind != .whitespace }
        var output = ""
        var level = 0
        var index = 0

        func newline() {
            output += "\n" + String(repeating: indent, count: max(0, level))
        }

        while index < tokens.count {
            let token = tokens[index]
            switch (token.kind, token.text) {
            case (.punctuation, "{"), (.punctuation, "["):
                output += token.text
                let closing = token.text == "{" ? "}" : "]"
                if index + 1 < tokens.count, tokens[index + 1].kind == .punctuation, tokens[index + 1].text == closing {
                    output += closing
                    index += 1
                } else {
                    level += 1
                    newline()
                }
            case (.punctuation, "}"), (.punctuation, "]"):
                level -= 1
                newline()
                output += token.text
            case (.punctuation, ","):
                output += ","
                newline()
            case (.punctuation, ":"):
                output += ": "
            default:
                output += token.text
            }
            index += 1
        }
        return output
    }

    /// Splits JSON text into tokens. Invalid input still produces tokens (kind `.other`),
    /// so it can be highlighted as far as it goes. Joining the texts gives back the input.
    public static func tokenize(_ text: String) -> [JSONToken] {
        let characters = Array(text)
        var tokens: [JSONToken] = []
        var index = 0

        while index < characters.count {
            let character = characters[index]
            if character.isWhitespace {
                var end = index
                while end < characters.count, characters[end].isWhitespace { end += 1 }
                tokens.append(JSONToken(.whitespace, String(characters[index..<end])))
                index = end
            } else if "{}[]:,".contains(character) {
                tokens.append(JSONToken(.punctuation, String(character)))
                index += 1
            } else if character == "\"" {
                var end = index + 1
                var isEscaped = false
                while end < characters.count {
                    let next = characters[end]
                    if isEscaped {
                        isEscaped = false
                    } else if next == "\\" {
                        isEscaped = true
                    } else if next == "\"" {
                        break
                    }
                    end += 1
                }
                end = min(end + 1, characters.count)
                tokens.append(JSONToken(.string, String(characters[index..<end])))
                index = end
            } else if character == "-" || isDigit(character) {
                var end = index + 1
                while end < characters.count, isNumberPart(characters[end]) { end += 1 }
                tokens.append(JSONToken(.number, String(characters[index..<end])))
                index = end
            } else if character.isLetter {
                var end = index + 1
                while end < characters.count, characters[end].isLetter { end += 1 }
                let word = String(characters[index..<end])
                let isLiteral = word == "true" || word == "false" || word == "null"
                tokens.append(JSONToken(isLiteral ? .literal : .other, word))
                index = end
            } else {
                tokens.append(JSONToken(.other, String(character)))
                index += 1
            }
        }

        markKeys(in: &tokens)
        return tokens
    }

    private static func markKeys(in tokens: inout [JSONToken]) {
        for index in tokens.indices where tokens[index].kind == .string {
            var next = index + 1
            while next < tokens.count, tokens[next].kind == .whitespace { next += 1 }
            if next < tokens.count, tokens[next].kind == .punctuation, tokens[next].text == ":" {
                tokens[index].kind = .key
            }
        }
    }

    private static func isDigit(_ character: Character) -> Bool {
        character.isASCII && character.isNumber
    }

    private static func isNumberPart(_ character: Character) -> Bool {
        isDigit(character) || character == "." || character == "e" || character == "E" || character == "+" || character == "-"
    }
}
