#if os(iOS)
import Foundation
import HealthKit

/// Reads monthly daily-averages from Santé (Apple Health). iPhone only; the Mac receives them through sync.
@MainActor
final class HealthService {
    static let shared = HealthService()
    private let hk = HKHealthStore()

    func fetchMonths() async -> [HealthMonth] {
        guard HKHealthStore.isHealthDataAvailable() else { return [] }
        let quantities: [HKQuantityTypeIdentifier] = [.stepCount, .distanceWalkingRunning, .activeEnergyBurned, .restingHeartRate, .flightsClimbed]
        var read = Set<HKObjectType>(quantities.map { HKQuantityType($0) })
        read.insert(HKCategoryType(.sleepAnalysis))
        do { try await hk.requestAuthorization(toShare: [], read: read) } catch { return [] }

        let thisMonth = Days.startOfMonth(Date())
        let start = Days.addMonths(-12, to: thisMonth)
        async let steps = monthly(.stepCount, .count(), .cumulativeSum, from: start)
        async let distance = monthly(.distanceWalkingRunning, .meterUnit(with: .kilo), .cumulativeSum, from: start)
        async let energy = monthly(.activeEnergyBurned, .kilocalorie(), .cumulativeSum, from: start)
        async let flights = monthly(.flightsClimbed, .count(), .cumulativeSum, from: start)
        async let heart = monthly(.restingHeartRate, .count().unitDivided(by: .minute()), .discreteAverage, from: start)
        async let sleep = sleepHours(from: start)
        let (s, d, e, f, h, sl) = await (steps, distance, energy, flights, heart, sleep)

        var out: [HealthMonth] = []
        var month = start
        while month <= thisMonth {
            let key = Days.monthKey(month)
            // Totals become per-day averages; the current month counts the days elapsed so far.
            let days = Double(month == thisMonth ? Days.calendar.component(.day, from: Date()) : Days.daysInMonth(month).count)
            let perDay = { (v: Double?) in v.map { $0 / days } }
            let m = HealthMonth(key: key, steps: perDay(s[key]), distanceKm: perDay(d[key]), activeKcal: perDay(e[key]),
                                restingHR: h[key], sleepHours: sl[key], flights: perDay(f[key]))
            if [m.steps, m.distanceKm, m.activeKcal, m.restingHR, m.sleepHours, m.flights].contains(where: { $0 != nil }) {
                out.append(m)
            }
            month = Days.addMonths(1, to: month)
        }
        return out
    }

    private func monthly(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit, _ options: HKStatisticsOptions, from start: Date) async -> [String: Double] {
        await withCheckedContinuation { cont in
            let q = HKStatisticsCollectionQuery(
                quantityType: HKQuantityType(id),
                quantitySamplePredicate: HKQuery.predicateForSamples(withStart: start, end: Date()),
                options: options, anchorDate: start, intervalComponents: DateComponents(month: 1))
            q.initialResultsHandler = { _, results, _ in
                var out: [String: Double] = [:]
                results?.enumerateStatistics(from: start, to: Date()) { stat, _ in
                    let q = options.contains(.cumulativeSum) ? stat.sumQuantity() : stat.averageQuantity()
                    if let v = q?.doubleValue(for: unit) { out[Days.monthKey(stat.startDate)] = v }
                }
                cont.resume(returning: out)
            }
            hk.execute(q)
        }
    }

    /// Average hours asleep per tracked night. Overlapping samples (phone + watch) are counted once.
    private func sleepHours(from start: Date) async -> [String: Double] {
        let samples: [HKCategorySample] = await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: HKCategoryType(.sleepAnalysis),
                                  predicate: HKQuery.predicateForSamples(withStart: start, end: Date()),
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, results, _ in
                cont.resume(returning: (results as? [HKCategorySample]) ?? [])
            }
            hk.execute(q)
        }
        let asleep = HKCategoryValueSleepAnalysis.allAsleepValues.map(\.rawValue)
        let intervals = samples.filter { asleep.contains($0.value) }
            .map { ($0.startDate, $0.endDate) }
            .sorted { $0.0 < $1.0 }
        var merged: [(Date, Date)] = []
        for i in intervals {
            if let last = merged.last, i.0 <= last.1 { merged[merged.count - 1].1 = max(last.1, i.1) } else { merged.append(i) }
        }
        var seconds: [String: Double] = [:]
        var nights: [String: Set<String>] = [:]
        for (s, e) in merged {
            // A night belongs to the day you wake up.
            let night = Days.calendar.startOfDay(for: e)
            let key = Days.monthKey(night)
            seconds[key, default: 0] += e.timeIntervalSince(s)
            nights[key, default: []].insert(Days.key(night))
        }
        return seconds.reduce(into: [:]) { out, kv in
            out[kv.key] = kv.value / 3600 / Double(max(1, nights[kv.key]?.count ?? 1))
        }
    }
}
#endif
