import Foundation
import Observation

enum DayStatus { case perfect, missed, today, future, none }

struct ActivityCount: Identifiable, Hashable {
    var id: String { title }
    var title: String
    var done: Int
    var scheduled: Int
}

@MainActor @Observable
final class AppStore {
    private(set) var data: AppData
    /// Ticks every 30 s so the day rolls over at 02:00 while the app is open.
    private(set) var now = Date()
    let sync = SyncService()

    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var timer: Timer?

    /// How many full months of daily detail to keep before only the monthly statistics remain.
    static let keepMonths = 3

    init() {
        data = Self.load()
        data = Self.housekeep(data, now: now)
        sync.snapshot = { [weak self] in self?.data ?? AppData() }
        sync.onReceive = { [weak self] remote in self?.receive(remote) }
        sync.start()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        save()
    }

    // MARK: Today

    var today: Date { Days.appDay(now) }
    var todayKey: String { Days.key(today) }
    var todayRecord: DayRecord { data.days[todayKey] ?? Self.snapshot(todayKey, data.activeSchedule) }
    var fuel: Fuel { Quotes.forDay(today) }

    var streak: Int {
        var count = todayRecord.isPerfect ? 1 : 0
        var day = Days.addDays(-1, to: today)
        while let r = data.days[Days.key(day)], r.isPerfect {
            count += 1
            day = Days.addDays(-1, to: day)
        }
        return count
    }

    var todaysWorkouts: [Workout] {
        data.activeWorkouts.filter { Days.appDay($0.date) == today }.sorted { $0.date > $1.date }
    }

    func note(_ kind: NoteKind) -> String { data.notes[kind.rawValue]?.text ?? "" }

    // MARK: Changes

    func toggle(_ item: ScheduleItem) {
        mutate { d in
            let key = Days.todayKey(self.now)
            var r = d.days[key] ?? Self.snapshot(key, d.activeSchedule)
            let id = item.id.uuidString
            r.ticks[id] = Tick(done: !r.isDone(id), modified: Date())
            d.days[key] = r
        }
    }

    func save(item: ScheduleItem) {
        mutate { d in
            var item = item
            item.modified = Date()
            if let i = d.schedule.firstIndex(where: { $0.id == item.id }) { d.schedule[i] = item } else { d.schedule.append(item) }
        }
    }

    func delete(item: ScheduleItem) {
        var item = item
        item.deleted = true
        save(item: item)
    }

    func setNote(_ kind: NoteKind, _ text: String) {
        mutate { $0.notes[kind.rawValue] = Note(text: text, modified: Date()) }
    }

    func add(workout: Workout) {
        mutate { $0.workouts.append(workout) }
    }

    func delete(workout: Workout) {
        mutate { d in
            guard let i = d.workouts.firstIndex(where: { $0.id == workout.id }) else { return }
            d.workouts[i].deleted = true
            d.workouts[i].modified = Date()
        }
    }

    func updateHealth(_ months: [HealthMonth]) {
        let changed = months.filter { m in
            guard let old = data.health[m.key] else { return true }
            var a = old, b = m
            a.modified = .distantPast; b.modified = .distantPast
            return a != b
        }
        guard !changed.isEmpty else { return }
        mutate { d in for m in changed { d.health[m.key] = m } }
    }

    func becameActive() {
        now = Date()
        data = Self.housekeep(data, now: now)
        sync.restart()
    }

    private func tick() {
        let before = todayKey
        now = Date()
        if todayKey != before {
            data = Self.housekeep(data, now: now)
            scheduleSave()
        }
    }

    private func mutate(_ change: (inout AppData) -> Void) {
        var d = data
        change(&d)
        d = Self.housekeep(d, now: now)
        guard d != data else { return }
        data = d
        scheduleSave()
    }

    private func receive(_ remote: AppData) {
        let merged = Self.housekeep(data.merged(with: remote), now: Date())
        if merged != data {
            data = merged
            save()
        }
        // The other device is missing something we have: send it back.
        if merged != remote { sync.broadcast(merged) }
    }

    // MARK: History queries

    func record(for day: Date) -> DayRecord? {
        Days.key(day) == todayKey ? todayRecord : data.days[Days.key(day)]
    }

    func status(for day: Date) -> DayStatus {
        if day > today { return .future }
        if day == today { return todayRecord.isPerfect ? .perfect : .today }
        guard let r = data.days[Days.key(day)], !r.items.isEmpty else { return .none }
        return r.isPerfect ? .perfect : .missed
    }

    func counts(for days: [Date]) -> [ActivityCount] {
        Self.counts(days.compactMap { record(for: $0) })
    }

    /// Times each activity was done in a month: live while daily detail exists, from the summary afterwards.
    func monthCounts(_ monthStart: Date) -> [ActivityCount] {
        let key = Days.monthKey(monthStart)
        let records = Days.daysInMonth(monthStart).compactMap { record(for: $0) }
        if records.isEmpty, let s = data.months[key] {
            return s.activityCounts.map { ActivityCount(title: $0.key, done: $0.value, scheduled: 0) }
                .sorted { ($1.done, $0.title) < ($0.done, $1.title) }
        }
        return Self.counts(records).sorted { ($1.done, $0.title) < ($0.done, $1.title) }
    }

    func workouts(from start: Date, to end: Date) -> [Workout] {
        data.activeWorkouts.filter { Days.appDay($0.date) >= start && Days.appDay($0.date) < end }
    }

    /// Schedule completion for a month (0–1): frozen summary for past months, live for the current one.
    func completion(_ monthKey: String) -> Double? {
        if let s = data.months[monthKey], s.criteria > 0 { return s.completion }
        guard monthKey == Days.monthKey(today) else { return nil }
        let s = Self.summarize(monthKey, data)
        return s.criteria > 0 ? s.completion : nil
    }

    /// The most recent finished month (sport statistics are only computed once a month is over).
    var lastFinishedMonth: MonthSummary? {
        data.months[Days.monthKey(Days.addMonths(-1, to: Days.startOfMonth(today)))]
    }

    // MARK: Housekeeping

    private static func snapshot(_ key: String, _ schedule: [ScheduleItem]) -> DayRecord {
        DayRecord(key: key, items: Dictionary(uniqueKeysWithValues: schedule.map { ($0.id.uuidString, $0.title) }))
    }

    private static func counts(_ records: [DayRecord]) -> [ActivityCount] {
        var done: [String: Int] = [:], scheduled: [String: Int] = [:], order: [String] = []
        for r in records {
            for (id, title) in r.items {
                if scheduled[title] == nil { order.append(title) }
                scheduled[title, default: 0] += 1
                if r.isDone(id) { done[title, default: 0] += 1 }
            }
        }
        return order.map { ActivityCount(title: $0, done: done[$0] ?? 0, scheduled: scheduled[$0] ?? 0) }
    }

    static func summarize(_ monthKey: String, _ d: AppData) -> MonthSummary {
        let records = d.days.values.filter { Days.monthKey(ofDayKey: $0.key) == monthKey && !$0.items.isEmpty }
        let workouts = d.activeWorkouts.filter { Days.monthKey(Days.appDay($0.date)) == monthKey }
        var activity: [String: Int] = [:]
        for c in counts(records) { activity[c.title] = c.done }
        return MonthSummary(
            key: monthKey,
            ticks: records.reduce(0) { $0 + $1.doneCount },
            criteria: records.reduce(0) { $0 + $1.items.count },
            perfectDays: records.filter(\.isPerfect).count,
            missedDays: records.filter { !$0.isPerfect }.count,
            activityCounts: activity,
            sports: Sport.summarize(workouts),
            cardioMinutes: workouts.filter { Sport.isCardio($0.sport) }.reduce(0) { $0 + $1.minutes })
    }

    /// Keeps the data consistent; safe to run any number of times.
    /// 1. today's record follows the current schedule; 2. days the app was never opened count as missed;
    /// 3. finished months get their summary; 4. daily detail older than `keepMonths` is deleted.
    static func housekeep(_ input: AppData, now: Date) -> AppData {
        var d = input
        let today = Days.appDay(now)
        let todayKey = Days.key(today)
        let schedule = d.activeSchedule

        var r = d.days[todayKey] ?? snapshot(todayKey, schedule)
        r.items = snapshot(todayKey, schedule).items
        if r.items.isEmpty && r.ticks.isEmpty { d.days[todayKey] = nil } else { d.days[todayKey] = r }

        if !schedule.isEmpty, let last = d.days.keys.filter({ $0 < todayKey }).max(), let lastDate = Days.date(last) {
            var day = Days.addDays(1, to: lastDate)
            while day < today {
                let k = Days.key(day)
                if d.days[k] == nil { d.days[k] = snapshot(k, schedule) }
                day = Days.addDays(1, to: day)
            }
        }

        let currentMonth = Days.monthKey(today)
        let monthsWithDetail = Set(d.days.keys.map(Days.monthKey(ofDayKey:)))
            .union(d.activeWorkouts.map { Days.monthKey(Days.appDay($0.date)) })
        for m in monthsWithDetail where m < currentMonth && d.months[m] == nil {
            d.months[m] = summarize(m, d)
        }

        let cutoff = Days.monthKey(Days.addMonths(-keepMonths, to: Days.startOfMonth(today)))
        let pruneBefore = max(cutoff, d.prunedBefore ?? cutoff)
        d.days = d.days.filter { Days.monthKey(ofDayKey: $0.key) >= pruneBefore }
        d.workouts = d.workouts.filter { Days.monthKey(Days.appDay($0.date)) >= pruneBefore }
        d.prunedBefore = pruneBefore
        return d
    }

    // MARK: Persistence

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Performance", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("data.json")
    }

    private static func load() -> AppData {
        guard let raw = try? Data(contentsOf: fileURL),
              let d = try? JSONDecoder().decode(AppData.self, from: raw) else { return AppData() }
        return d
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled, let self else { return }
            self.save()
            self.sync.broadcast(self.data)
        }
    }

    private func save() {
        guard let raw = try? JSONEncoder().encode(data) else { return }
        try? raw.write(to: Self.fileURL, options: .atomic)
    }
}
