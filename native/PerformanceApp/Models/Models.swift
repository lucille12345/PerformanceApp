import Foundation

/// A recurring activity on the daily schedule. Ticks reset every day at 02:00.
struct ScheduleItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    /// Minutes after midnight the activity must be completed by.
    var dueMinutes: Int
    var modified = Date()
    var deleted = false

    var dueText: String { String(format: "%02d:%02d", dueMinutes / 60, dueMinutes % 60) }
}

struct Tick: Codable, Hashable {
    var done: Bool
    var modified: Date
}

/// What was scheduled and ticked on one app day (an app day runs 02:00 → 01:59).
struct DayRecord: Codable, Hashable {
    var key: String
    /// Snapshot of the schedule that day: item id → title.
    var items: [String: String]
    var ticks: [String: Tick] = [:]

    func isDone(_ id: String) -> Bool { ticks[id]?.done == true }
    var doneCount: Int { items.keys.filter(isDone).count }
    var isPerfect: Bool { !items.isEmpty && doneCount == items.count }
}

enum NoteKind: String, Codable, CaseIterable, Identifiable {
    case todo, projects, goals, other
    var id: String { rawValue }
    var label: String {
        switch self {
        case .todo: "TO DO"
        case .projects: "PROJECTS"
        case .goals: "LONG-TERM GOALS"
        case .other: "OTHER"
        }
    }
}

struct Note: Codable, Hashable {
    var text = ""
    var modified = Date.distantPast
}

struct Workout: Codable, Identifiable, Hashable {
    var id = UUID()
    var date = Date()
    var minutes: Double
    var pace: String
    var sport: String
    var calories: Int?
    var modified = Date()
    var deleted = false
}

enum PaceStyle: String, Codable { case perKm, per100m, speed }

struct SportSummary: Codable, Hashable, Identifiable {
    var id: String { name }
    var name: String
    var minutes: Double
    var sessions: Int
    var avgKmh: Double?
    var style: PaceStyle
}

/// Frozen statistics for a finished month. Kept forever; daily detail is pruned after 3 months.
struct MonthSummary: Codable, Hashable {
    var key: String
    var ticks: Int
    var criteria: Int
    var perfectDays: Int
    var missedDays: Int
    var activityCounts: [String: Int]
    var sports: [SportSummary]
    var cardioMinutes: Double
    var modified = Date()

    var completion: Double { criteria == 0 ? 0 : Double(ticks) / Double(criteria) }
    var sportMinutes: Double { sports.reduce(0) { $0 + $1.minutes } }
}

/// Monthly daily-averages read from Santé (Apple Health) on the iPhone.
struct HealthMonth: Codable, Hashable {
    var key: String
    var steps: Double?
    var distanceKm: Double?
    var activeKcal: Double?
    var restingHR: Double?
    var sleepHours: Double?
    var flights: Double?
    var modified = Date()
}

struct AppData: Codable, Equatable {
    var schedule: [ScheduleItem] = []
    var days: [String: DayRecord] = [:]
    var notes: [String: Note] = [:]
    var workouts: [Workout] = []
    var months: [String: MonthSummary] = [:]
    var health: [String: HealthMonth] = [:]
    /// Month key; daily detail before this month has been deleted and must not come back through sync.
    var prunedBefore: String?

    var activeSchedule: [ScheduleItem] {
        schedule.filter { !$0.deleted }.sorted { ($0.dueMinutes, $0.title) < ($1.dueMinutes, $1.title) }
    }
    var activeWorkouts: [Workout] { workouts.filter { !$0.deleted } }
}
