import SwiftUI

/// The tabs of ``RequestDetailView``.
public enum RequestDetailTab: String, CaseIterable, Identifiable, Sendable {
    case overview
    case request
    case response

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .overview: "Overview"
        case .request: "Request"
        case .response: "Response"
        }
    }
}

/// Everything about one request, in Overview / Request / Response tabs, with cURL sharing.
public struct RequestDetailView: View {
    private let record: NetworkRecord
    @State private var tab: RequestDetailTab

    public init(record: NetworkRecord, initialTab: RequestDetailTab = .overview) {
        self.record = record
        _tab = State(initialValue: initialTab)
    }

    public var body: some View {
        let curl = CURLBuilder.command(for: record)

        List {
            Section {
                DetailHeader(record: record)
                Picker("Section", selection: $tab) {
                    ForEach(RequestDetailTab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            switch tab {
            case .overview:
                OverviewSections(record: record)
            case .request:
                RequestSections(record: record)
            case .response:
                ResponseSections(record: record)
            }
        }
        .navigationTitle(title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                ShareLink(item: curl) {
                    Label("Share cURL", systemImage: "square.and.arrow.up")
                }
                Menu {
                    Button("Copy cURL", systemImage: "terminal") {
                        Pasteboard.copy(curl)
                    }
                    Button("Copy URL", systemImage: "link") {
                        Pasteboard.copy(record.url.absoluteString)
                    }
                    if let body = BodyContent(data: record.responseBody).copyableText {
                        Button("Copy Response Body", systemImage: "doc.on.doc") {
                            Pasteboard.copy(body)
                        }
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
    }

    private var title: String {
        let last = record.url.lastPathComponent
        return last.isEmpty || last == "/" ? record.host : last
    }
}

// MARK: - Header

struct DetailHeader: View {
    let record: NetworkRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                MethodBadge(method: record.method)
                StatusBadge(record: record)
                if let code = record.statusCode {
                    Text(HTTPStatus.reasonPhrase(for: code))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(record.category.tint)
                }
                Spacer(minLength: 0)
                if let duration = record.duration {
                    Label(NetTraceFormat.duration(duration), systemImage: "timer")
                        .labelStyle(CompactLabelStyle())
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            Text(record.url.absoluteString)
                .font(.system(.footnote, design: .monospaced))
                .lineLimit(5)
                .textSelection(.enabled)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Tabs

struct OverviewSections: View {
    let record: NetworkRecord

    var body: some View {
        Section("General") {
            InfoRow(title: "Method", value: record.method)
            InfoRow(title: "Status", value: statusText)
            InfoRow(title: "Host", value: record.host)
            InfoRow(title: "Path", value: record.pathAndQuery)
            InfoRow(title: "Scheme", value: record.url.scheme?.uppercased() ?? "-")
        }

        Section("Timing") {
            InfoRow(title: "Started", value: record.startDate.formatted(date: .abbreviated, time: .standard))
            if let end = record.endDate {
                InfoRow(title: "Finished", value: end.formatted(date: .omitted, time: .standard))
            }
            InfoRow(title: "Duration", value: record.duration.map { NetTraceFormat.duration($0) } ?? "Pending")
        }

        Section("Size") {
            InfoRow(title: "Request body", value: sizeText(record.requestBodySize, truncated: record.isRequestBodyTruncated))
            InfoRow(title: "Response body", value: sizeText(record.responseBodySize, truncated: record.isResponseBodyTruncated))
            if let type = record.responseContentType {
                InfoRow(title: "Content type", value: type)
            }
        }

        if let error = record.errorDescription {
            Section("Error") {
                Label(error, systemImage: "exclamationmark.octagon.fill")
                    .foregroundStyle(record.category.tint)
                    .textSelection(.enabled)
            }
        }
    }

    private var statusText: String {
        if let code = record.statusCode {
            return NetTraceFormat.status(code)
        }
        return record.isComplete ? "No response" : "Pending"
    }

    private func sizeText(_ bytes: Int, truncated: Bool) -> String {
        let size = NetTraceFormat.byteCount(bytes)
        return truncated ? "\(size) (partially captured)" : size
    }
}

struct RequestSections: View {
    let record: NetworkRecord

    var body: some View {
        HeaderSection(headers: record.requestHeaders)

        let query = record.queryItems
        if !query.isEmpty {
            Section {
                ForEach(Array(query.enumerated()), id: \.offset) { item in
                    KeyValueRow(name: item.element.name, value: item.element.value ?? "")
                }
            } header: {
                CountedHeader(title: "Query", count: query.count)
            }
        }

        BodySection(data: record.requestBody, totalSize: record.requestBodySize, contentType: record.requestContentType)
    }
}

struct ResponseSections: View {
    let record: NetworkRecord

    var body: some View {
        if let error = record.errorDescription {
            Section("Error") {
                Label(error, systemImage: "exclamationmark.octagon.fill")
                    .foregroundStyle(record.category.tint)
            }
        }
        if record.statusCode != nil || !record.responseHeaders.isEmpty {
            HeaderSection(headers: record.responseHeaders)
        }
        BodySection(data: record.responseBody, totalSize: record.responseBodySize, contentType: record.responseContentType)
    }
}

// MARK: - Building blocks

struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        LabeledContent(title) {
            Text(value)
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
        }
    }
}

struct KeyValueRow: View {
    let name: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(name)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? " " : value)
                .font(.system(.footnote, design: .monospaced))
                .foregroundStyle(value == Redactor.placeholder ? Color.orange : Color.primary)
                .textSelection(.enabled)
        }
        .padding(.vertical, 1)
    }
}

struct CountedHeader: View {
    let title: String
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            Text("\(count)")
                .font(.caption2.weight(.bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Color.secondary.opacity(0.18), in: Capsule())
        }
    }
}

struct HeaderSection: View {
    let headers: [String: String]

    var body: some View {
        let sorted = headers.sorted { $0.key.lowercased() < $1.key.lowercased() }
        Section {
            if sorted.isEmpty {
                Text("No headers")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(sorted, id: \.key) { header in
                    KeyValueRow(name: header.key, value: header.value)
                }
            }
        } header: {
            CountedHeader(title: "Headers", count: sorted.count)
        }
    }
}
