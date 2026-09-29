import SwiftUI

/// One request in the list: method, path, status, host, duration, size and time.
struct RequestRow: View {
    let record: NetworkRecord

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            MethodBadge(method: record.method)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(record.pathAndQuery)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .truncationMode(.middle)
                    Spacer(minLength: 4)
                    StatusBadge(record: record)
                }

                Text(record.host)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let error = record.errorDescription {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(record.category.tint)
                        .lineLimit(1)
                }

                HStack(spacing: 12) {
                    Label(durationText, systemImage: "timer")
                    Label(NetTraceFormat.byteCount(record.responseBodySize), systemImage: "arrow.down.circle")
                    Spacer(minLength: 0)
                    Text(record.startDate, format: .dateTime.hour().minute().second())
                }
                .labelStyle(CompactLabelStyle())
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
    }

    private var durationText: String {
        record.duration.map { NetTraceFormat.duration($0) } ?? "Pending"
    }
}

struct CompactLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon
            configuration.title
        }
    }
}
