import SwiftUI

struct HistoryView: View {
    @State private var month = false

    var body: some View {
        Screen {
            HStack {
                Text("HISTORY").font(.num(34))
                Spacer()
                HStack(spacing: 0) {
                    segment("WEEK", selected: !month) { month = false }
                    segment("MONTH", selected: month) { month = true }
                }
                .padding(3)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(.top, 8)
            if month { MonthHistory() } else { WeekHistory() }
        }
    }

    private func segment(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 12, weight: .bold)).tracking(1)
                .padding(.horizontal, 16).frame(height: 38)
                .background(selected ? Theme.line : .clear, in: RoundedRectangle(cornerRadius: 8))
                .foregroundStyle(selected ? Theme.text : Theme.muted)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// Day number with a green (everything ticked) or red ring.
struct DayCircle: View {
    var day: Date
    var status: DayStatus
    var selected: Bool
    var size: CGFloat = 40

    var body: some View {
        Text(Days.format(day, "d"))
            .font(.num(size * 0.44))
            .foregroundStyle(status == .future || status == .none ? Theme.dim : Theme.text)
            .frame(width: size, height: size)
            .background(selected ? Theme.line : .clear, in: Circle())
            .overlay {
                switch status {
                case .perfect: Circle().strokeBorder(Theme.green, lineWidth: 3)
                case .missed: Circle().strokeBorder(Theme.red, lineWidth: 3)
                case .today: Circle().strokeBorder(Theme.faint, style: StrokeStyle(lineWidth: 3, dash: [4, 3]))
                case .future, .none: EmptyView()
                }
            }
    }
}

// MARK: Week

struct WeekHistory: View {
    @Environment(AppStore.self) private var store
    @State private var offset = 0
    @State private var selected: Date?

    private var start: Date { Days.addDays(offset * 7, to: Days.startOfWeek(store.today)) }
    private var days: [Date] { (0..<7).map { Days.addDays($0, to: start) } }

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 12) {
                HStack {
                    ArrowButton(left: true) { move(-1) }
                    Spacer()
                    Text(title).font(.num(20))
                    Spacer()
                    ArrowButton(left: false) { move(1) }
                }
                HStack(spacing: 4) {
                    ForEach(days, id: \.self) { d in
                        Button { selected = selected == d ? nil : d } label: {
                            VStack(spacing: 6) {
                                Text(Days.format(d, "EEE").uppercased()).font(.system(size: 11, weight: .bold)).tracking(1)
                                    .foregroundStyle(Theme.muted)
                                DayCircle(day: d, status: store.status(for: d), selected: selected == d)
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if let d = selected {
                DayDetail(day: d)
            } else {
                TotalsCard(title: "THIS WEEK", counts: store.counts(for: days))
                WeekTraining(workouts: store.workouts(from: start, to: Days.addDays(7, to: start)))
            }
        }
        .swipe(previous: { move(-1) }, next: { move(1) })
    }

    private var title: String {
        let end = days.last!
        let sameMonth = Days.calendar.isDate(start, equalTo: end, toGranularity: .month)
        return (sameMonth ? Days.format(start, "d") : Days.format(start, "d MMM")).uppercased() + " – " + Days.format(end, "d MMM").uppercased()
    }

    private func move(_ n: Int) { offset += n; selected = nil }
}

struct TotalsCard: View {
    var title: String
    var counts: [ActivityCount]

    var body: some View {
        let done = counts.reduce(0) { $0 + $1.done }, total = counts.reduce(0) { $0 + $1.scheduled }
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(title)
                Spacer()
                if total > 0 { (Text("\(done)") + Text("/\(total)").foregroundStyle(Theme.dim)).font(.num(18)) }
            }
            .padding(.bottom, 8)
            if counts.isEmpty { Text("No data").font(.system(size: 14)).foregroundStyle(Theme.dim).padding(.vertical, 8) }
            ForEach(counts) { c in
                VStack(spacing: 8) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(c.title).font(.system(size: 15, weight: .semibold))
                        Spacer()
                        (Text("\(c.done)") + Text(c.scheduled > 0 ? "/\(c.scheduled)" : "").font(.num(14)).foregroundStyle(Theme.dim)).font(.num(20))
                    }
                    Bar(value: c.scheduled > 0 ? Double(c.done) / Double(c.scheduled) : Double(c.done) / Double(max(1, counts.map(\.done).max() ?? 1)))
                }
                .padding(.vertical, 12)
                .overlay(alignment: .top) { Theme.line.frame(height: 1) }
            }
        }
        .card()
    }
}

struct WeekTraining: View {
    var workouts: [Workout]
    var body: some View {
        if !workouts.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionLabel("TRAINING")
                HStack(spacing: 8) {
                    tile(Fmt.hours(workouts.reduce(0) { $0 + $1.minutes }), "HOURS")
                    tile("\(workouts.count)", "SESSIONS")
                    let kcal = workouts.compactMap(\.calories).reduce(0, +)
                    tile(kcal > 0 ? Fmt.thousands(Double(kcal)) : "—", "KCAL")
                }
            }
            .card()
        }
    }

    private func tile(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(value).font(.num(24))
            Text(label).font(.system(size: 10)).tracking(1).foregroundStyle(Theme.muted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card2, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct DayDetail: View {
    @Environment(AppStore.self) private var store
    var day: Date

    var body: some View {
        let record = store.record(for: day)
        let workouts = store.workouts(from: day, to: Days.addDays(1, to: day))
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(Days.format(day, "EEE d MMM").uppercased())
                Spacer()
                if let r = record, !r.items.isEmpty {
                    Text("\(r.doneCount)/\(r.items.count)").font(.num(18))
                        .foregroundStyle(r.isPerfect ? Theme.green : (day < store.today ? Color(hex: 0xFF6B6B) : Theme.text))
                }
            }
            .padding(.bottom, 8)
            if let r = record, !r.items.isEmpty {
                ForEach(r.items.sorted { $0.value < $1.value }, id: \.key) { id, title in
                    let done = r.isDone(id)
                    HStack(spacing: 12) {
                        ZStack {
                            if done {
                                RoundedRectangle(cornerRadius: 6).fill(Theme.accent)
                                Image(systemName: "checkmark").font(.system(size: 11, weight: .heavy)).foregroundStyle(.black)
                            } else {
                                RoundedRectangle(cornerRadius: 6).strokeBorder(Theme.faint, lineWidth: 2)
                            }
                        }
                        .frame(width: 20, height: 20)
                        Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(done ? Theme.text : Theme.dim)
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .top) { Theme.line.frame(height: 1) }
                }
            } else {
                Text("No data").font(.system(size: 14)).foregroundStyle(Theme.dim).padding(.vertical, 8)
            }
            if !workouts.isEmpty {
                VStack(spacing: 8) { ForEach(workouts) { WorkoutRow(workout: $0) } }.padding(.top, 12)
            }
        }
        .card()
    }
}

// MARK: Month

struct MonthHistory: View {
    @Environment(AppStore.self) private var store
    @State private var offset = 0
    @State private var selected: Date?

    private var monthStart: Date { Days.addMonths(offset, to: Days.startOfMonth(store.today)) }

    var body: some View {
        let days = Days.daysInMonth(monthStart)
        let lead = (Days.calendar.component(.weekday, from: monthStart) + 5) % 7 // Monday = 0
        let statuses = days.map { store.status(for: $0) }
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                HStack {
                    ArrowButton(left: true) { move(-1) }
                    Spacer()
                    Text(Days.format(monthStart, "MMMM yyyy").uppercased()).font(.num(20))
                    Spacer()
                    ArrowButton(left: false) { move(1) }
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 6) {
                    ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { _, w in
                        Text(w).font(.system(size: 11, weight: .bold)).tracking(1).foregroundStyle(Theme.muted)
                    }
                    ForEach(0..<lead, id: \.self) { _ in Color.clear.frame(height: 44) }
                    ForEach(Array(days.enumerated()), id: \.offset) { i, d in
                        Button { selected = selected == d ? nil : d } label: {
                            DayCircle(day: d, status: statuses[i], selected: selected == d, size: 42)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                let summary = store.data.months[Days.monthKey(monthStart)]
                let green = statuses.contains(where: { $0 == .perfect || $0 == .missed })
                    ? statuses.filter { $0 == .perfect }.count : (summary?.perfectDays ?? 0)
                let red = statuses.contains(where: { $0 == .perfect || $0 == .missed })
                    ? statuses.filter { $0 == .missed }.count : (summary?.missedDays ?? 0)
                if green + red > 0 {
                    HStack(spacing: 16) {
                        legend(Theme.green, green)
                        legend(Theme.red, red)
                    }
                    .padding(.top, 6)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 12)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))

            if let d = selected { DayDetail(day: d) }
            MonthTotals(title: Days.format(monthStart, "MMMM").uppercased(), counts: store.monthCounts(monthStart))
        }
        .swipe(previous: { move(-1) }, next: { move(1) })
    }

    private func legend(_ color: Color, _ n: Int) -> some View {
        HStack(spacing: 6) {
            Circle().strokeBorder(color, lineWidth: 2).frame(width: 10, height: 10)
            Text("\(n)").font(.system(size: 12)).foregroundStyle(Theme.muted)
        }
    }

    private func move(_ n: Int) { offset += n; selected = nil }
}

struct MonthTotals: View {
    var title: String
    var counts: [ActivityCount]

    var body: some View {
        let top = Double(max(1, counts.map(\.done).max() ?? 1))
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                SectionLabel(title)
                Spacer()
                Text("times done").font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            .padding(.bottom, 8)
            if counts.isEmpty { Text("No data").font(.system(size: 14)).foregroundStyle(Theme.dim).padding(.vertical, 8) }
            ForEach(counts) { c in
                HStack(spacing: 12) {
                    Text(c.title).font(.system(size: 15, weight: .medium)).lineLimit(1).frame(width: 130, alignment: .leading)
                    Bar(value: Double(c.done) / top)
                    Text("\(c.done)").font(.num(20)).frame(width: 30, alignment: .trailing)
                }
                .padding(.vertical, 10)
                .overlay(alignment: .top) { Theme.line.frame(height: 1) }
            }
        }
        .card()
    }
}
