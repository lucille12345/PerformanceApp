import Charts
import SwiftUI

/// Everything below this point comes from Santé (Apple Health), not from what was logged in the app.
struct HealthSection: View {
    @Environment(AppStore.self) private var store
    var months: [Date]

    private struct Metric: Identifiable {
        var id: String { label }
        var label: String
        var value: String
        var unit: String
        var trend: [Double]
    }

    var body: some View {
        let health = store.data.health
        // Show the last finished month once it exists, otherwise the current month so far.
        let lastKey = Days.monthKey(Days.addMonths(-1, to: Days.startOfMonth(store.today)))
        let shownKey = health[lastKey] != nil ? lastKey : Days.monthKey(store.today)
        let shown = health[shownKey]
        let history = health.keys.sorted().filter { $0 <= shownKey }.suffix(8).compactMap { health[$0] }

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Theme.health, in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 0) {
                    Text("SANTÉ").font(.system(size: 12, weight: .bold)).tracking(2).foregroundStyle(Theme.healthSoft)
                    if shown != nil, let start = Days.monthStart(shownKey) {
                        Text("Daily activity · \(Days.format(start, "MMMM"))").font(.system(size: 12)).foregroundStyle(Theme.healthMuted)
                    }
                }
            }

            if let m = shown {
                let metrics = [
                    Metric(label: "STEPS", value: m.steps.map { Fmt.thousands($0) } ?? "—", unit: "/day", trend: history.compactMap(\.steps)),
                    Metric(label: "DISTANCE", value: m.distanceKm.map { String(format: "%.1f", $0) } ?? "—", unit: "km/day", trend: history.compactMap(\.distanceKm)),
                    Metric(label: "ACTIVE ENERGY", value: m.activeKcal.map { Fmt.thousands($0) } ?? "—", unit: "kcal/day", trend: history.compactMap(\.activeKcal)),
                    Metric(label: "RESTING HR", value: m.restingHR.map { "\(Int($0.rounded()))" } ?? "—", unit: "bpm", trend: history.compactMap(\.restingHR)),
                    Metric(label: "SLEEP", value: m.sleepHours.map { Fmt.hours($0 * 60) } ?? "—", unit: "h/night", trend: history.compactMap(\.sleepHours)),
                    Metric(label: "FLIGHTS", value: m.flights.map { "\(Int($0.rounded()))" } ?? "—", unit: "/day", trend: history.compactMap(\.flights)),
                ]
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(metrics) { tile($0) }
                }
                MonthlyBars(title: "STEPS / DAY · MONTHLY AVG", months: months, color: Theme.healthSoft,
                            trailing: m.steps.map { (Fmt.thousands($0), Theme.text) },
                            labelColor: Color(hex: 0x8A7076), fill: Theme.healthCard, titleColor: Theme.healthMuted,
                            format: { $0 >= 1000 ? "\(Int($0 / 1000))k" : "\(Int($0))" }) {
                    store.data.health[Days.monthKey($0)]?.steps
                }
            } else {
                Text(emptyText).font(.system(size: 14)).foregroundStyle(Theme.healthMuted).padding(.vertical, 6)
            }
        }
        .padding(.horizontal, 12).padding(.top, 18).padding(.bottom, 12)
        .background(Theme.healthBg, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.healthLine))
        .padding(.top, 20)
    }

    private var emptyText: String {
        #if os(iOS)
        "No data from Santé yet"
        #else
        "No data from Santé yet — it arrives from your iPhone"
        #endif
    }

    private func tile(_ m: Metric) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(m.label).font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(Theme.healthMuted)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(m.value).font(.num(26))
                Text(m.unit).font(.system(size: 11)).foregroundStyle(Theme.healthMuted)
            }
            Chart(Array(m.trend.enumerated()), id: \.offset) { i, v in
                LineMark(x: .value("i", i), y: .value("v", v))
                    .foregroundStyle(Theme.healthSoft)
                    .interpolationMethod(.catmullRom)
            }
            .chartXAxis(.hidden)
            .chartYAxis(.hidden)
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 28)
            .opacity(m.trend.count > 1 ? 1 : 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.healthCard, in: RoundedRectangle(cornerRadius: 12))
    }
}
