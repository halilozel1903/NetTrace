import SwiftUI

/// What a body looks like once decoded.
enum BodyContent {
    case empty
    case json(String)
    case text(String)
    case binary(Int)

    init(data: Data?) {
        guard let data, !data.isEmpty else {
            self = .empty
            return
        }
        if let pretty = JSONFormatter.prettyPrinted(data) {
            self = .json(pretty)
        } else if let text = String(data: data, encoding: .utf8) {
            self = .text(text)
        } else {
            self = .binary(data.count)
        }
    }

    var copyableText: String? {
        switch self {
        case .json(let text), .text(let text): text
        case .empty, .binary: nil
        }
    }

    var kindLabel: String {
        switch self {
        case .empty: "Empty"
        case .json: "JSON"
        case .text: "Text"
        case .binary: "Binary"
        }
    }
}

/// The body section: syntax-highlighted JSON, plain text or a binary summary, with a copy button.
struct BodySection: View {
    let content: BodyContent
    let capturedSize: Int
    let totalSize: Int
    let contentType: String?

    init(data: Data?, totalSize: Int, contentType: String?) {
        self.content = BodyContent(data: data)
        self.capturedSize = data?.count ?? 0
        self.totalSize = totalSize
        self.contentType = contentType
    }

    var body: some View {
        Section {
            switch content {
            case .empty:
                Text(totalSize > 0 ? "Body not captured" : "No body")
                    .foregroundStyle(.secondary)
            case .json(let text):
                Text(JSONHighlighter.highlight(text))
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .text(let text):
                Text(text)
                    .font(.system(.footnote, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            case .binary(let count):
                Label("\(NetTraceFormat.byteCount(count)) of binary data", systemImage: "doc.zipper")
                    .foregroundStyle(.secondary)
            }
        } header: {
            HStack {
                Text("Body")
                Text(summary)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .textCase(nil)
                Spacer()
                if let text = content.copyableText {
                    Button("Copy", systemImage: "doc.on.doc") {
                        Pasteboard.copy(text)
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                }
            }
        } footer: {
            if capturedSize < totalSize {
                Text("Showing the first \(NetTraceFormat.byteCount(capturedSize)) of \(NetTraceFormat.byteCount(totalSize)).")
            }
        }
    }

    private var summary: String {
        var parts = [content.kindLabel]
        if totalSize > 0 {
            parts.append(NetTraceFormat.byteCount(totalSize))
        }
        if case .empty = content, let contentType {
            parts.append(contentType)
        }
        return parts.joined(separator: " · ")
    }
}

/// Colors JSON tokens.
enum JSONHighlighter {
    static func highlight(_ json: String) -> AttributedString {
        var result = AttributedString()
        for token in JSONFormatter.tokenize(json) {
            var part = AttributedString(token.text)
            let tint: Color = color(for: token.kind)
            part.foregroundColor = tint
            result.append(part)
        }
        return result
    }

    static func color(for kind: JSONToken.Kind) -> Color {
        switch kind {
        case .key: .purple
        case .string: .red
        case .number: .blue
        case .literal: .pink
        case .punctuation: .secondary
        case .whitespace, .other: .primary
        }
    }
}
