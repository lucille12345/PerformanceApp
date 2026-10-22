import Foundation

enum Sport {
    /// Parses what was typed in the TIME field: "45" (minutes), "45:30", "1:05:00".
    static func minutes(from text: String) -> Double? {
        let parts = text.trimmingCharacters(in: .whitespaces).split(separator: ":").map { Double($0.trimmingCharacters(in: .whitespaces)) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 != nil }) else { return nil }
        let p = parts.map { $0! }
        switch p.count {
        case 1: return p[0]
        case 2: return p[0] + p[1] / 60
        case 3: return p[0] * 60 + p[1] + p[2] / 60
        default: return nil
        }
    }

    /// Parses the PACE field: "5:10" or "5:10/km" (per km), "2:05/100m" (swim), "27" or "27 km/h" (speed).
    static func speed(from text: String) -> (kmh: Double, style: PaceStyle)? {
        let t = text.lowercased().replacingOccurrences(of: ",", with: ".")
        if t.contains(":") {
            let clock = t.split(whereSeparator: { !"0123456789:.".contains($0) }).first.map(String.init) ?? ""
            let p = clock.split(separator: ":").compactMap { Double($0) }
            guard p.count == 2 else { return nil }
            let secs = p[0] * 60 + p[1]
            guard secs > 0 else { return nil }
            if t.contains("100") { return (360 / secs, .per100m) }
            if t.contains("mi") { return (3600 / secs * 1.609, .perKm) }
            return (3600 / secs, .perKm)
        }
        let num = t.split(whereSeparator: { !"0123456789.".contains($0) }).first.flatMap { Double($0) }
        guard let v = num, v > 0 else { return nil }
        return (t.contains("mph") ? v * 1.609 : v, .speed)
    }

    static func paceText(kmh: Double, style: PaceStyle) -> (value: String, unit: String) {
        switch style {
        case .speed: return (String(format: "%.1f", kmh), "KM/H")
        case .perKm:
            let s = Int((3600 / kmh).rounded())
            return (String(format: "%d:%02d", s / 60, s % 60), "/KM")
        case .per100m:
            let s = Int((360 / kmh).rounded())
            return (String(format: "%d:%02d", s / 60, s % 60), "/100M")
        }
    }

    private static let cardioWords = ["run", "jog", "course", "footing", "trail", "cycl", "bike", "vélo", "velo", "swim", "natation",
                                      "row", "aviron", "rameur", "hiit", "cardio", "skip", "corde", "elliptic", "spin", "walk", "marche",
                                      "hike", "rando", "box", "ski", "danse", "dance", "stair", "escalier", "triathlon", "cross"]

    static func isCardio(_ sport: String) -> Bool {
        let s = sport.lowercased()
        return cardioWords.contains { s.contains($0) }
    }

    /// Normalises sport names so "running", "Running " and "RUNNING" count as one.
    static func displayName(_ sport: String) -> String {
        let s = sport.trimmingCharacters(in: .whitespacesAndNewlines)
        return s.prefix(1).uppercased() + s.dropFirst().lowercased()
    }

    /// Per-sport totals, most minutes first.
    static func summarize(_ workouts: [Workout]) -> [SportSummary] {
        let groups = Dictionary(grouping: workouts) { displayName($0.sport) }
        return groups.map { name, list in
            let minutes = list.reduce(0) { $0 + $1.minutes }
            let timed = list.compactMap { w in speed(from: w.pace).map { (w.minutes, $0) } }
            let timedMinutes = timed.reduce(0) { $0 + $1.0 }
            // Time-weighted average speed; shown in the style used most often.
            let avg = timedMinutes > 0 ? timed.reduce(0) { $0 + $1.0 * $1.1.kmh } / timedMinutes : nil
            let style = Dictionary(grouping: timed, by: { $0.1.style }).max { $0.value.count < $1.value.count }?.key ?? .speed
            return SportSummary(name: name, minutes: minutes, sessions: list.count, avgKmh: avg, style: style)
        }.sorted { $0.minutes > $1.minutes }
    }
}
