import Foundation

/// Calendar helpers. An "app day" starts at 02:00, so 01:30 on Friday still counts as Thursday.
enum Days {
    static let resetHour = 2
    static var calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2 // Monday
        c.locale = Locale(identifier: "en_GB")
        return c
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Midnight of the app day containing `date`.
    static func appDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date.addingTimeInterval(-Double(resetHour) * 3600))
    }

    static func key(_ day: Date) -> String { dayFormatter.string(from: day) }
    static func date(_ key: String) -> Date? { dayFormatter.date(from: key) }
    static func todayKey(_ now: Date = Date()) -> String { key(appDay(now)) }

    static func monthKey(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year!, c.month!)
    }
    static func monthKey(ofDayKey key: String) -> String { String(key.prefix(7)) }

    static func startOfMonth(_ date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date))!
    }
    static func monthStart(_ key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: 1))
    }
    static func addMonths(_ n: Int, to date: Date) -> Date { calendar.date(byAdding: .month, value: n, to: date)! }
    static func addDays(_ n: Int, to date: Date) -> Date { calendar.date(byAdding: .day, value: n, to: date)! }

    static func startOfWeek(_ date: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)!.start
    }
    static func daysInMonth(_ monthStart: Date) -> [Date] {
        let range = calendar.range(of: .day, in: .month, for: monthStart)!
        return range.map { addDays($0 - 1, to: monthStart) }
    }

    static func format(_ date: Date, _ format: String) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_GB")
        f.dateFormat = format
        return f.string(from: date)
    }
}

enum Fmt {
    /// 75 → "1:15"
    static func hours(_ minutes: Double) -> String {
        let m = Int(minutes.rounded())
        return String(format: "%d:%02d", m / 60, m % 60)
    }
    /// 45 → "45:00", 75 → "1:15:00"
    static func duration(_ minutes: Double) -> String {
        let s = Int((minutes * 60).rounded())
        return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, s / 60 % 60, s % 60)
                         : String(format: "%d:%02d", s / 60, s % 60)
    }
    static func thousands(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = " "
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: v)) ?? "\(Int(v))"
    }
}
