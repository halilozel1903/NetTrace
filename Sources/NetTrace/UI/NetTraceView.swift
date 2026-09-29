import SwiftUI

/// The inspector: a searchable, filterable list of requests that opens a detail screen.
///
/// Present it yourself, or let ``SwiftUI/View/netTrace(_:isEnabled:store:)`` show it on a shake
/// or from a floating button.
public struct NetTraceView: View {
    @State private var inspector: NetTraceInspector
    @Environment(\.dismiss) private var dismiss
    private let showsDoneButton: Bool

    /// - Parameters:
    ///   - store: The store to show. Defaults to the one NetTrace records into.
    ///   - showsDoneButton: Adds a Done button that dismisses the view, for sheets.
    public init(store: NetTraceStore = NetTrace.store, showsDoneButton: Bool = false) {
        _inspector = State(initialValue: NetTraceInspector(store: store))
        self.showsDoneButton = showsDoneButton
    }

    public var body: some View {
        NavigationStack {
            RequestListView(inspector: inspector)
                .navigationTitle("Network")
                .navigationDestination(for: NetworkRecord.ID.self) { id in
                    RecordDestination(inspector: inspector, id: id)
                }
                #if os(iOS)
                .searchable(
                    text: $inspector.filter.searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "URL, method or status"
                )
                #else
                .searchable(text: $inspector.filter.searchText, prompt: "URL, method or status")
                #endif
                .toolbar { toolbarContent }
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if showsDoneButton {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            filterMenu
            Button(role: .destructive) {
                inspector.clear()
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .disabled(inspector.records.isEmpty)
        }
    }

    private var filterMenu: some View {
        Menu {
            Section("Method") {
                ForEach(inspector.availableMethods, id: \.self) { method in
                    Button {
                        inspector.filter.toggle(method: method)
                    } label: {
                        if inspector.filter.methods.contains(method) {
                            Label(method, systemImage: "checkmark")
                        } else {
                            Text(method)
                        }
                    }
                }
            }
            if inspector.filter.isActive {
                Button("Reset Filters", systemImage: "xmark.circle") {
                    inspector.filter = RecordFilter()
                }
            }
        } label: {
            Label(
                "Filter",
                systemImage: inspector.filter.methods.isEmpty
                    ? "line.3.horizontal.decrease.circle"
                    : "line.3.horizontal.decrease.circle.fill"
            )
        }
    }
}

/// The list itself, without navigation.
struct RequestListView: View {
    let inspector: NetTraceInspector

    var body: some View {
        let records = inspector.filteredRecords
        List {
            if !inspector.records.isEmpty {
                Section {
                    SummaryStrip(records: inspector.records)
                    CategoryChips(inspector: inspector)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
            }

            if !records.isEmpty {
                Section {
                    ForEach(records) { record in
                        NavigationLink(value: record.id) {
                            RequestRow(record: record)
                        }
                    }
                } header: {
                    Text(headerText(shown: records.count))
                }
            }
        }
        .overlay {
            if inspector.records.isEmpty {
                ContentUnavailableView(
                    "No Requests Yet",
                    systemImage: "network",
                    description: Text("Requests made through URLSession appear here as they happen.")
                )
            } else if records.isEmpty {
                ContentUnavailableView.search(text: inspector.filter.searchText)
            }
        }
    }

    private func headerText(shown: Int) -> String {
        let total = inspector.records.count
        let noun = total == 1 ? "request" : "requests"
        return inspector.filter.isActive ? "\(shown) of \(total) \(noun)" : "\(total) \(noun)"
    }
}

struct RecordDestination: View {
    let inspector: NetTraceInspector
    let id: NetworkRecord.ID

    var body: some View {
        if let record = inspector.record(id: id) {
            RequestDetailView(record: record)
        } else {
            ContentUnavailableView(
                "Request Cleared",
                systemImage: "trash",
                description: Text("This request is no longer in the store.")
            )
        }
    }
}

// MARK: - Summary

struct SummaryStrip: View {
    let records: [NetworkRecord]

    private static let errorCategories: Set<StatusCategory> = [.clientError, .serverError, .failed]

    var body: some View {
        let errors = records.filter { Self.errorCategories.contains($0.category) }.count
        let received = records.reduce(0) { $0 + $1.responseBodySize }
        let durations = records.compactMap(\.duration)
        let average = durations.isEmpty ? nil : durations.reduce(0, +) / Double(durations.count)

        HStack(spacing: 8) {
            StatTile(value: "\(records.count)", title: "Requests", systemImage: "arrow.up.arrow.down", tint: .blue)
            StatTile(value: "\(errors)", title: "Errors", systemImage: "exclamationmark.triangle", tint: errors > 0 ? .red : .green)
            StatTile(value: NetTraceFormat.byteCount(received), title: "Received", systemImage: "arrow.down.circle", tint: .purple)
            StatTile(value: average.map { NetTraceFormat.duration($0) } ?? "-", title: "Average", systemImage: "timer", tint: .orange)
        }
    }
}

struct StatTile: View {
    let value: String
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
            Text(value)
                .font(.headline.monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct CategoryChips: View {
    let inspector: NetTraceInspector

    var body: some View {
        let counts = Dictionary(grouping: inspector.records, by: \.category).mapValues(\.count)
        let categories = StatusCategory.allCases.filter { counts[$0] != nil }

        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(categories) { category in
                    let isOn = inspector.filter.categories.contains(category)
                    Button {
                        inspector.filter.toggle(category: category)
                    } label: {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(category.tint)
                                .frame(width: 8, height: 8)
                            Text(category.title)
                            Text("\(counts[category] ?? 0)")
                                .foregroundStyle(.secondary)
                        }
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(isOn ? category.tint.opacity(0.22) : Color.secondary.opacity(0.12), in: Capsule())
                        .overlay(Capsule().strokeBorder(isOn ? category.tint.opacity(0.7) : Color.clear, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
    }
}
