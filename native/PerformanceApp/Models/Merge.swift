import Foundation

/// Combines the data of two devices. Every piece carries a `modified` date and the newest wins,
/// so merging is order-independent and both devices end up identical.
extension AppData {
    func merged(with other: AppData) -> AppData {
        var out = AppData()
        out.schedule = Self.mergeByID(schedule, other.schedule, id: \.id, modified: \.modified)
        out.workouts = Self.mergeByID(workouts, other.workouts, id: \.id, modified: \.modified)
        out.notes = Self.mergeDict(notes, other.notes) { $0.modified >= $1.modified ? $0 : $1 }
        out.months = Self.mergeDict(months, other.months) { $0.modified >= $1.modified ? $0 : $1 }
        out.health = Self.mergeDict(health, other.health) { $0.modified >= $1.modified ? $0 : $1 }
        out.days = Self.mergeDict(days, other.days) { a, b in
            var r = a
            r.items.merge(b.items) { x, _ in x }
            r.ticks = Self.mergeDict(a.ticks, b.ticks) { $0.modified >= $1.modified ? $0 : $1 }
            return r
        }
        out.prunedBefore = [prunedBefore, other.prunedBefore].compactMap { $0 }.max()
        return out
    }

    private static func mergeByID<T, ID: Hashable & Comparable>(_ a: [T], _ b: [T], id: KeyPath<T, ID>, modified: KeyPath<T, Date>) -> [T] {
        var byID: [ID: T] = [:]
        for item in a + b {
            if let existing = byID[item[keyPath: id]], existing[keyPath: modified] >= item[keyPath: modified] { continue }
            byID[item[keyPath: id]] = item
        }
        // Stable order so both devices compare equal after a merge.
        return byID.values.sorted { $0[keyPath: id] < $1[keyPath: id] }
    }

    private static func mergeDict<V>(_ a: [String: V], _ b: [String: V], pick: (V, V) -> V) -> [String: V] {
        a.merging(b) { pick($0, $1) }
    }
}
