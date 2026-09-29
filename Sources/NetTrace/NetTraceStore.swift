import Foundation

/// A thread-safe, size-limited list of ``NetworkRecord``s, newest first.
///
/// The URL protocol writes to it from URLSession's delegate queues; the inspector UI
/// observes it on the main actor. You can also fill a store yourself, for previews or tests.
public final class NetTraceStore: Sendable {
    /// Called after every change with a monotonically increasing version and the new records.
    public typealias Observer = @Sendable (_ version: Int, _ records: [NetworkRecord]) -> Void

    private struct State {
        var records: [NetworkRecord]
        var maxRecords: Int
        var version = 0
        var observers: [UUID: Observer] = [:]
    }

    private let state: Locked<State>

    /// - Parameters:
    ///   - maxRecords: How many records to keep; the oldest are dropped first.
    ///   - records: Initial records, newest first.
    public init(maxRecords: Int = 500, records: [NetworkRecord] = []) {
        let limit = max(1, maxRecords)
        state = Locked(State(records: Array(records.prefix(limit)), maxRecords: limit))
    }

    /// All records, newest first.
    public var records: [NetworkRecord] {
        state.withLock { $0.records }
    }

    public var count: Int {
        state.withLock { $0.records.count }
    }

    public var maxRecords: Int {
        get { state.withLock { $0.maxRecords } }
        set {
            let limit = max(1, newValue)
            mutate { state in
                state.maxRecords = limit
                Self.trim(&state)
            }
        }
    }

    /// The records together with the version they belong to.
    public func snapshot() -> (version: Int, records: [NetworkRecord]) {
        state.withLock { ($0.version, $0.records) }
    }

    public func record(id: UUID) -> NetworkRecord? {
        state.withLock { state in state.records.first { $0.id == id } }
    }

    /// Adds a record at the top.
    public func insert(_ record: NetworkRecord) {
        mutate { state in
            state.records.insert(record, at: 0)
            Self.trim(&state)
        }
    }

    /// Changes the record with `id` in place. Does nothing when it was dropped or cleared.
    public func update(id: UUID, _ change: (inout NetworkRecord) -> Void) {
        mutate { state in
            if let index = state.records.firstIndex(where: { $0.id == id }) {
                change(&state.records[index])
            }
        }
    }

    public func clear() {
        mutate { $0.records.removeAll() }
    }

    /// Registers `observer`. It runs on the thread that changed the store, outside the lock.
    @discardableResult
    public func addObserver(id: UUID = UUID(), _ observer: @escaping Observer) -> UUID {
        state.withLock { $0.observers[id] = observer }
        return id
    }

    public func removeObserver(_ id: UUID) {
        state.withLock { _ = $0.observers.removeValue(forKey: id) }
    }

    private func mutate(_ body: (inout State) -> Void) {
        let (version, records, observers) = state.withLock { (state: inout State) -> (Int, [NetworkRecord], [Observer]) in
            body(&state)
            state.version += 1
            return (state.version, state.records, Array(state.observers.values))
        }
        for observer in observers {
            observer(version, records)
        }
    }

    private static func trim(_ state: inout State) {
        let overflow = state.records.count - state.maxRecords
        if overflow > 0 {
            state.records.removeLast(overflow)
        }
    }
}
