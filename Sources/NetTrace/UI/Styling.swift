import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension StatusCategory {
    var tint: Color {
        switch self {
        case .pending: .gray
        case .success: .green
        case .redirect: .blue
        case .clientError: .orange
        case .serverError: .red
        case .failed: .pink
        }
    }
}

enum MethodStyle {
    static func tint(for method: String) -> Color {
        switch method.uppercased() {
        case "GET": .blue
        case "POST": .green
        case "PUT": .orange
        case "PATCH": .purple
        case "DELETE": .red
        case "HEAD", "OPTIONS": .teal
        default: .gray
        }
    }
}

/// A small colored capsule with the HTTP method.
struct MethodBadge: View {
    let method: String

    var body: some View {
        let tint = MethodStyle.tint(for: method)
        Text(method)
            .font(.system(.caption2, design: .monospaced).weight(.bold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .foregroundStyle(tint)
            .frame(width: 58)
            .padding(.vertical, 4)
            .background(tint.opacity(0.14), in: Capsule())
            .overlay(Capsule().strokeBorder(tint.opacity(0.3), lineWidth: 0.5))
    }
}

/// The status code (or a spinner / error mark) in the category color.
struct StatusBadge: View {
    let record: NetworkRecord

    var body: some View {
        let tint = record.category.tint
        Group {
            if let code = record.statusCode {
                Text(String(code))
            } else if record.isComplete {
                Image(systemName: "exclamationmark.triangle.fill")
            } else {
                ProgressView()
                    .controlSize(.mini)
            }
        }
        .font(.system(.caption, design: .rounded).weight(.bold))
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(tint.opacity(0.15), in: Capsule())
    }
}

extension View {
    /// Interactive Liquid Glass on iOS 26 / macOS 26, a regular material before.
    @ViewBuilder
    func netTraceGlass(in shape: some Shape) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            glassEffect(.regular.interactive(), in: shape)
        } else {
            background(.regularMaterial, in: shape)
                .overlay(shape.stroke(Color.primary.opacity(0.12), lineWidth: 0.5))
        }
    }
}

enum Pasteboard {
    @MainActor
    static func copy(_ string: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = string
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
        #endif
    }
}
