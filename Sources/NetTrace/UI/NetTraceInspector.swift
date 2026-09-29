import Foundation
import Observation

/// Observes a ``NetTraceStore`` on the main actor and holds the list's filter.
///
/// ``NetTraceView`` creates one for you; use it directly to build your own inspector UI.
@MainActor
@Observable
public final class NetTraceInspector {
    public let store: NetTraceStore

    /// Every record in the store, newest first.
    public private(set) var records: [NetworkRecord]

    /// The search text and method / status filters.
    public var filter = RecordFilter()

    @ObservationIgnored private var version: Int
    private let observerID: UUID

    public init(store: NetTraceStore = NetTrace.store) {
        self.store = store
        let snapshot = store.snapshot()
        self.records = snapshot.records
        self.version = snapshot.version
        self.observerID = UUID()

        store.addObserver(id: observerID) { [weak self] version, records in
            guard let inspector = self else { return }
            Task { @MainActor in
                inspector.apply(version: version, records: records)
            }
        }
    }

    deinit {
        store.removeObserver(observerID)
    }

    /// The records that pass ``filter``.
    public var filteredRecords: [NetworkRecord] {
        filter.apply(to: records)
    }

    /// Methods present in the store, for the filter menu.
    public var availableMethods: [String] {
        RecordFilter.methods(in: records)
    }

    public func record(id: NetworkRecord.ID) -> NetworkRecord? {
        records.first { $0.id == id }
    }

    /// Empties the store.
    public func clear() {
        store.clear()
    }

    private func apply(version: Int, records: [NetworkRecord]) {
        // Tasks can arrive out of order; only ever move forward.
        guard version > self.version else { return }
        self.version = version
        self.records = records
    }
}
