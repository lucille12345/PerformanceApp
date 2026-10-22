import Charts
import SwiftUI

struct StatsView: View {
    @Environment(AppStore.self) private var store
    @State private var yearOffset = 0

    private var year: Int { Days.calendar.component(.year, from: store.today) + yearOffset }
    private var months: [Date] { (1...12).map { Days.calendar.date(from: DateComponents(year: year, month: $0, day: 1))! } }

    var body: some View {
        Screen {
            HStack {
                Text("STATS").font(.num(34))
                Spacer()
                ArrowButton(left: true) { withAnimation(.snappy) { yearOffset -= 1 } }
                Text(String(year)).font(.num(20))
                ArrowButton(left: false, enabled: yearOffset < 0) { withAnimation(.snappy) { yearOffset += 1 } }
            }
            .padding(.top, 8)

            Group {
                SourceDivider(title: "THIS APP", color: Theme.accent, line: Color(hex: 0x1E4A5E))
                CompletionChart(months: months)
                if let last = store.lastFinishedMonth, yearOffset == 0 { SportMonthCard(summary: last) }
                MonthlyBars(title: "SPORT HOURS / MONTH", months: months, color: Theme.accent, trailing: sportDelta) {
                    store.data.months[Days.monthKey($0)].map { $0.sportMinutes / 60 }
                }
                MonthlyBars(title: "CARDIO HOURS / MONTH", months: months, color: Theme.orange,
                            trailing: store.lastFinishedMonth.map { (Fmt.hours($0.cardioMinutes), Theme.orange) }) {
                    store.data.months[Days.monthKey($0)].map { $0.cardioMinutes / 60 }
                }
            }
            .contentShape(Rectangle())
            .swipe(previous: { yearOffset -= 1 }, next: { if yearOffset < 0 { yearOffset += 1 } })

            HealthSection(months: months)
        }
    }

    /// Sport hours of the last finished month compared with the month before.
    private var sportDelta: (String, Color)? {
        guard let last = store.lastFinishedMonth else { return nil }
        let prevKey = Days.monthKey(Days.addMonths(-2, to: Days.startOfMonth(store.today)))
        guard let prev = store.data.months[prevKey] else { return (Fmt.hours(last.sportMinutes), Theme.text) }
        let diff = last.sportMinutes - prev.sportMinutes
        return ((diff >= 0 ? "+" : "−") + Fmt.hours(abs(diff)), diff >= 0 ? Theme.green : Theme.red)
    }
}

struct SourceDivider: View {
    var title: String
    var color: Color
    var line: Color
    var body: some View {
        HStack(spacing: 10) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(title).font(.system(size: 12, weight: .bold)).tracking(2).foregroundStyle(color)
            line.frame(height: 1)
        }
        .padding(.top, 4)
    }
}

// MARK: Schedule completion

struct CompletionChart: View {
    @Environment(AppStore.self) private var store
    var months: [Date]

    private struct Point: Identifiable {
        var id: String { label }
        var label: String
        var pct: Double?
        var live: Bool
    }

    var body: some View {
        let current = Days.monthKey(store.today)
        let points = months.map { m -> Point in
            let key = Days.monthKey(m)
            return Point(label: Days.format(m, "MMM").uppercased(), pct: store.completion(key).map { $0 * 100 }, live: key == current)
        }
        let finished = points.filter { !$0.live }.compactMap(\.pct)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("SCHEDULE COMPLETED")
                Spacer()
                if !finished.isEmpty {
                    Text("\(Int((finished.reduce(0, +) / Double(finished.count)).rounded()))%").font(.num(22))
                    + Text(" avg").font(.system(size: 11)).foregroundStyle(Theme.muted)
                }
            }
            Chart(points) { p in
                BarMark(xStart: .value("Start", 0), xEnd: .value("Completed", 100), y: .value("Month", p.label), height: 12)
                    .foregroundStyle(Theme.card2)
                    .cornerRadius(3)
                if let v = p.pct {
                    BarMark(xStart: .value("Start", 0), xEnd: .value("Completed", v), y: .value("Month", p.label), height: 12)
                        .foregroundStyle(p.live ? Theme.accent.opacity(0.5) : Theme.accent)
                        .cornerRadius(3)
                        .annotation(position: .trailing, alignment: .leading, spacing: 4) {
                            Text("\(Int(v.rounded()))%").font(.num(13)).foregroundStyle(p.live ? Theme.muted : Theme.text)
                        }
                }
            }
            .chartXScale(domain: 0...112)
            .chartYScale(domain: points.map(\.label))
            .chartXAxis {
                AxisMarks(values: [0, 50, 100]) { v in
                    AxisGridLine().foregroundStyle(Theme.line)
                    AxisValueLabel { Text("\(v.as(Int.self) ?? 0)%").font(.system(size: 10)).foregroundStyle(Theme.dim) }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { v in
                    AxisValueLabel { Text(v.as(String.self) ?? "").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.muted) }
                }
            }
            .frame(height: 340)
        }
        .card()
    }
}

// MARK: Sport

struct SportMonthCard: View {
    var summary: MonthSummary

    var body: some View {
        let top = max(1, summary.sports.first?.minutes ?? 1)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel("SPORT · " + (Days.monthStart(summary.key).map { Days.format($0, "MMMM") } ?? summary.key).uppercased())
                Spacer()
                let sessions = summary.sports.reduce(0) { $0 + $1.sessions }
                Text("\(sessions) session\(sessions == 1 ? "" : "s")").font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Fmt.hours(summary.sportMinutes)).font(.num(52))
                Text("hours").font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
            VStack(spacing: 0) {
                ForEach(Array(summary.sports.enumerated()), id: \.element.id) { i, s in
                    HStack(spacing: 12) {
                        Text("\(i + 1)").font(.num(18)).foregroundStyle(Theme.dim).frame(width: 22, alignment: .leading)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(s.name).font(.system(size: 15, weight: .semibold))
                            Bar(value: s.minutes / top, height: 4)
                        }
                        stat(Fmt.hours(s.minutes), "HOURS")
                        if let kmh = s.avgKmh {
                            let p = Sport.paceText(kmh: kmh, style: s.style)
                            stat(p.value, p.unit)
                        } else {
                            stat("—", "")
                        }
                    }
                    .padding(.vertical, 12)
                    .overlay(alignment: .top) { Theme.line.frame(height: 1) }
                }
            }
        }
        .card()
    }

    private func stat(_ value: String, _ unit: String) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(value).font(.num(18))
            Text(unit).font(.system(size: 10)).tracking(1).foregroundStyle(Theme.muted)
        }
        .frame(width: 64, alignment: .trailing)
    }
}

/// Vertical bars for each month of the year.
struct MonthlyBars: View {
    var title: String
    var months: [Date]
    var color: Color
    var trailing: (String, Color)?
    var labelColor = Theme.dim
    var fill = Theme.card
    var titleColor = Theme.muted
    var format: (Double) -> String = { Fmt.hours($0 * 60) }
    var value: (Date) -> Double?

    private struct Point: Identifiable {
        var id: String { label }
        var label: String
        var value: Double
    }

    var body: some View {
        let points = months.map { Point(label: Days.format($0, "MMM"), value: value($0) ?? 0) }
        let latest = points.lastIndex { $0.value > 0 }
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(title, color: titleColor)
                Spacer()
                if let trailing { Text(trailing.0).font(.num(18)).foregroundStyle(trailing.1) }
            }
            Chart(Array(points.enumerated()), id: \.element.id) { i, p in
                BarMark(x: .value("Month", p.label), y: .value("Value", p.value), width: .ratio(0.7))
                    .foregroundStyle(i == latest ? color : color.opacity(0.6))
                    .cornerRadius(3)
            }
            .chartXScale(domain: points.map(\.label))
            .chartXAxis {
                AxisMarks { v in
                    AxisValueLabel { Text(String((v.as(String.self) ?? "").prefix(1))).font(.system(size: 10, weight: .bold)).foregroundStyle(labelColor) }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { v in
                    AxisGridLine().foregroundStyle(Theme.line.opacity(0.6))
                    AxisValueLabel { Text(format(v.as(Double.self) ?? 0)).font(.system(size: 10)).foregroundStyle(labelColor) }
                }
            }
            .frame(height: 140)
        }
        .card(fill)
    }
}
