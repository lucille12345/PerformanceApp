import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Screen {
            header
            FuelCard(fuel: store.fuel)
            HStack(alignment: .top, spacing: 12) {
                CalendarCard()
                StreakCard(days: store.streak).frame(width: 112)
            }
            .fixedSize(horizontal: false, vertical: true)
            ScheduleCard()
            NotesGrid()
            TrainingCard()
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(Days.format(store.today, "EEEE").uppercased())
                    .font(.system(size: 13, weight: .semibold)).tracking(1.5).foregroundStyle(Theme.muted)
                Text(Days.format(store.today, "d MMM").uppercased()).font(.num(34))
            }
            Spacer()
            let peers = store.sync.peerNames
            HStack(spacing: 6) {
                Image(systemName: peers.isEmpty ? "wifi" : "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(peers.isEmpty ? Theme.faint : Theme.green)
                Text(([SyncService.deviceName] + peers).joined(separator: " · "))
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.muted)
        }
        .padding(.top, 8)
    }
}

// MARK: Quote / fact

struct FuelCard: View {
    var fuel: Fuel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionLabel(fuel.kind.rawValue, color: Theme.accent)
            Text(fuel.text).font(.system(size: 20, weight: .semibold)).lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
            Text(fuel.source).font(.system(size: 12)).foregroundStyle(Theme.muted)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .overlay(alignment: .top) { Theme.accent.frame(height: 3) }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

// MARK: Calendar

struct CalendarCard: View {
    @Environment(CalendarService.self) private var calendar
    @Environment(\.openURL) private var openURL
    private let maxRows = 4

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionLabel("CALENDAR")
                Spacer()
                if !calendar.events.isEmpty {
                    Text("\(calendar.events.count) event\(calendar.events.count == 1 ? "" : "s")")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.muted)
                }
            }
            .padding(.bottom, 6)

            if calendar.denied {
                row(color: Theme.faint, time: "", title: "No calendar access", event: nil)
            } else if calendar.events.isEmpty {
                row(color: Theme.faint, time: "", title: "Nothing today", event: nil)
            }
            ForEach(calendar.events.prefix(maxRows)) { e in
                row(color: e.color.map { Color(cgColor: $0) } ?? Theme.accent,
                    time: e.allDay ? "ALL" : Days.format(e.start, "HH:mm"), title: e.title, event: e)
            }
            if calendar.events.count > maxRows {
                row(color: Theme.faint, time: "", title: "+\(calendar.events.count - maxRows) more", event: nil)
            }
        }
        .card()
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .task { await calendar.refresh() }
    }

    private func row(color: Color, time: String, title: String, event: CalendarEvent?) -> some View {
        Button { openURL(calendar.url(for: event)) } label: {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 3, height: 26)
                if !time.isEmpty { Text(time).font(.num(16)).frame(width: 42, alignment: .leading) }
                Text(title).font(.system(size: 14, weight: .medium)).lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .bold)).foregroundStyle(Theme.dim)
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .overlay(alignment: .top) { Theme.line.frame(height: 1) }
        }
        .buttonStyle(.plain)
    }
}

// MARK: Streak

struct StreakCard: View {
    var days: Int
    var body: some View {
        VStack(spacing: 4) {
            Flame().frame(width: 52, height: 62)
            Text("\(days)").font(.num(40)).contentTransition(.numericText())
            Text("DAY STREAK").font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(Color(hex: 0xFFB066))
        }
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Theme.card
                RadialGradient(colors: [Color(hex: 0xFF7814).opacity(days > 0 ? 0.28 : 0.08), .clear],
                               center: .init(x: 0.5, y: 0.35), startRadius: 0, endRadius: 70)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

struct Flame: View {
    var body: some View {
        ZStack {
            FlamePath(outer: true).fill(LinearGradient(colors: [Color(hex: 0xFF3D00), Color(hex: 0xFF7A00), Color(hex: 0xFFC94A)],
                                                       startPoint: .bottom, endPoint: .top))
            FlamePath(outer: false).fill(LinearGradient(colors: [Color(hex: 0xFFB300), Color(hex: 0xFFF1BF)],
                                                        startPoint: .bottom, endPoint: .top))
        }
        .shadow(color: Color(hex: 0xFF5A00).opacity(0.5), radius: 10)
    }
}

/// Flame drawn in a 64×76 box, scaled to fit.
struct FlamePath: Shape {
    var outer: Bool
    func path(in r: CGRect) -> Path {
        let sx = r.width / 64, sy = r.height / 76
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: r.minX + x * sx, y: r.minY + y * sy) }
        var path = Path()
        if outer {
            path.move(to: p(32, 2))
            path.addCurve(to: p(54, 44), control1: p(36, 16), control2: p(52, 24))
            path.addCurve(to: p(32, 74), control1: p(56, 62), control2: p(45, 74))
            path.addCurve(to: p(10, 46), control1: p(19, 74), control2: p(8, 63))
            path.addCurve(to: p(21, 24), control1: p(11, 36), control2: p(17, 30))
            path.addCurve(to: p(29, 38), control1: p(22, 32), control2: p(25, 36))
            path.addCurve(to: p(32, 2), control1: p(27, 26), control2: p(28, 14))
        } else {
            path.move(to: p(32, 34))
            path.addCurve(to: p(43, 58), control1: p(36, 42), control2: p(44, 48))
            path.addCurve(to: p(32, 70), control1: p(42, 66), control2: p(37, 70))
            path.addCurve(to: p(22, 58), control1: p(26, 70), control2: p(21, 65))
            path.addCurve(to: p(30, 42), control1: p(23, 51), control2: p(28, 47))
            path.addCurve(to: p(35, 49), control1: p(31, 46), control2: p(33, 48))
            path.addCurve(to: p(32, 34), control1: p(34, 44), control2: p(33, 39))
        }
        path.closeSubpath()
        return path
    }
}

// MARK: Schedule

struct ScheduleCard: View {
    @Environment(AppStore.self) private var store
    @State private var editing: ScheduleItem?

    var body: some View {
        let record = store.todayRecord
        let items = store.data.activeSchedule
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                SectionLabel("SCHEDULE")
                Spacer()
                (Text("\(record.doneCount)") + Text("/\(items.count)").foregroundStyle(Theme.dim)).font(.num(18))
                Button { editing = ScheduleItem(title: "", dueMinutes: 18 * 60) } label: {
                    Image(systemName: "plus").font(.system(size: 16, weight: .bold))
                        .frame(width: 44, height: 44)
                        .background(Theme.card2, in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
                .accessibilityLabel("Add activity")
            }
            .padding(.bottom, 10)
            Bar(value: items.isEmpty ? 0 : Double(record.doneCount) / Double(items.count), height: 4).padding(.bottom, 6)

            ForEach(items) { item in
                let done = record.isDone(item.id.uuidString)
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.system(size: 16, weight: .semibold))
                            .strikethrough(done, color: Theme.dim)
                            .foregroundStyle(done ? Theme.dim : Theme.text)
                        Text("by \(item.dueText)").font(.system(size: 12)).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Button { withAnimation(.snappy) { store.toggle(item) } } label: {
                        ZStack {
                            if done {
                                RoundedRectangle(cornerRadius: 7).fill(Theme.accent).frame(width: 26, height: 26)
                                Image(systemName: "checkmark").font(.system(size: 14, weight: .heavy)).foregroundStyle(.black)
                            } else {
                                RoundedRectangle(cornerRadius: 7).strokeBorder(Theme.faint, lineWidth: 2).frame(width: 24, height: 24)
                            }
                        }
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(done ? "Mark \(item.title) not done" : "Mark \(item.title) done")
                }
                .frame(minHeight: 56)
                .overlay(alignment: .bottom) { Theme.line.frame(height: 1) }
                .contentShape(Rectangle())
                .contextMenu {
                    Button("Edit") { editing = item }
                    Button("Delete", role: .destructive) { store.delete(item: item) }
                }
            }
        }
        .card()
        .sheet(item: $editing) { item in ItemEditor(item: item) }
    }
}

struct ItemEditor: View {
    @Environment(AppStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State var item: ScheduleItem
    @FocusState private var focused: Bool

    private var due: Binding<Date> {
        Binding(
            get: { Days.calendar.date(bySettingHour: item.dueMinutes / 60, minute: item.dueMinutes % 60, second: 0, of: Date())! },
            set: { let c = Days.calendar.dateComponents([.hour, .minute], from: $0); item.dueMinutes = c.hour! * 60 + c.minute! })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SectionLabel("ACTIVITY")
            TextField("Activity", text: $item.title)
                .textFieldStyle(.plain)
                .font(.system(size: 20, weight: .semibold))
                .padding(12)
                .background(Theme.card2, in: RoundedRectangle(cornerRadius: 8))
                .focused($focused)
            HStack {
                SectionLabel("COMPLETE BY")
                Spacer()
                DatePicker("", selection: due, displayedComponents: .hourAndMinute).labelsHidden()
            }
            Spacer()
            HStack(spacing: 12) {
                Button("CANCEL") { dismiss() }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Theme.card2, in: RoundedRectangle(cornerRadius: 10))
                Button("SAVE") {
                    item.title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
                    store.save(item: item)
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.black)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Theme.accent, in: RoundedRectangle(cornerRadius: 10))
                .disabled(item.title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .font(.system(size: 14, weight: .bold))
        }
        .padding(20)
        .frame(minWidth: 320, minHeight: 280)
        .background(Theme.card)
        .foregroundStyle(Theme.text)
        .presentationDetents([.height(300)])
        .presentationBackground(Theme.card)
        .preferredColorScheme(.dark)
        .onAppear { focused = item.title.isEmpty }
    }
}

// MARK: Notes

struct NotesGrid: View {
    var body: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(NoteKind.allCases) { NoteBox(kind: $0) }
        }
    }
}

struct NoteBox: View {
    @Environment(AppStore.self) private var store
    var kind: NoteKind

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(kind.label).font(.label).tracking(1.5).foregroundStyle(Color(hex: 0x4A5258))
            TextEditor(text: Binding(get: { store.note(kind) }, set: { store.setNote(kind, $0) }))
                .font(.system(size: 14))
                .foregroundStyle(Theme.ink)
                .scrollContentBackground(.hidden)
                .tint(Theme.accent)
                .frame(minHeight: 130)
        }
        .padding(14)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .environment(\.colorScheme, .light)
    }
}

// MARK: Training

struct TrainingCard: View {
    @Environment(AppStore.self) private var store
    @State private var logging = false
    @State private var time = ""
    @State private var pace = ""
    @State private var sport = ""
    @State private var kcal = ""

    var body: some View {
        let workouts = store.todaysWorkouts
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionLabel("TRAINING")
                Spacer()
                if !workouts.isEmpty { Text("\(workouts.count) today").font(.system(size: 12)).foregroundStyle(Theme.muted) }
            }
            ForEach(workouts) { w in
                WorkoutRow(workout: w)
                    .contextMenu { Button("Delete", role: .destructive) { store.delete(workout: w) } }
            }
            if logging { form.transition(.opacity.combined(with: .move(edge: .top))) }
            Button { withAnimation(.snappy) { logging.toggle() } } label: {
                HStack(spacing: 8) {
                    Image(systemName: logging ? "xmark" : "plus").font(.system(size: 14, weight: .bold))
                    Text(logging ? "CANCEL" : "LOG WORKOUT").font(.system(size: 14, weight: .bold)).tracking(1.5)
                }
                .frame(maxWidth: .infinity, minHeight: 48)
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.line))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Theme.accent)
        }
        .card()
    }

    private var minutes: Double? { Sport.minutes(from: time) }
    private var canSave: Bool { (minutes ?? 0) > 0 && !sport.trimmingCharacters(in: .whitespaces).isEmpty }

    private var form: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                field("TIME", "45:00", $time, numeric: true)
                field("PACE", "5:10/km", $pace, numeric: false)
            }
            HStack(spacing: 10) {
                field("SPORT", "Running", $sport, numeric: false, condensed: false)
                field("KCAL", "—", $kcal, numeric: true, dashed: true)
            }
            Button {
                guard let m = minutes else { return }
                store.add(workout: Workout(minutes: m, pace: pace.trimmingCharacters(in: .whitespaces),
                                           sport: Sport.displayName(sport), calories: Int(kcal.trimmingCharacters(in: .whitespaces))))
                time = ""; pace = ""; sport = ""; kcal = ""
                withAnimation(.snappy) { logging = false }
            } label: {
                Text("SAVE").font(.system(size: 14, weight: .bold)).tracking(1.5)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(canSave ? Theme.accent : Theme.card2, in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(canSave ? .black : Theme.dim)
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
        }
        .padding(14)
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.line))
    }

    private func field(_ label: String, _ prompt: String, _ text: Binding<String>, numeric: Bool,
                       condensed: Bool = true, dashed: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(Theme.muted)
            TextField("", text: text, prompt: Text(prompt).foregroundStyle(Theme.faint))
                .textFieldStyle(.plain)
                .font(condensed ? .num(20) : .system(size: 16, weight: .semibold))
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(Theme.card2, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(dashed ? Color(hex: 0x3A4045) : Theme.line, style: StrokeStyle(lineWidth: 1, dash: dashed ? [4, 3] : [])))
                #if os(iOS)
                .keyboardType(numeric ? .numbersAndPunctuation : .default)
                #endif
                .accessibilityLabel(label)
        }
        .frame(maxWidth: .infinity)
    }
}

struct WorkoutRow: View {
    var workout: Workout
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: SportIcon.name(workout.sport))
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 40, height: 40)
                .background(Theme.accent.opacity(0.15), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(workout.sport).font(.system(size: 15, weight: .semibold))
                Text(Days.format(workout.date, "HH:mm")).font(.system(size: 12)).foregroundStyle(Theme.muted)
            }
            Spacer()
            stat(Fmt.duration(workout.minutes), "TIME")
            if let s = Sport.speed(from: workout.pace) {
                let p = Sport.paceText(kmh: s.kmh, style: s.style)
                stat(p.value, p.unit)
            }
            if let c = workout.calories { stat("\(c)", "KCAL") }
        }
        .padding(12)
        .background(Theme.card2, in: RoundedRectangle(cornerRadius: 10))
    }

    private func stat(_ value: String, _ unit: String) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(value).font(.num(18))
            Text(unit).font(.system(size: 10)).tracking(1).foregroundStyle(Theme.muted)
        }
    }
}

enum SportIcon {
    static func name(_ sport: String) -> String {
        let s = sport.lowercased()
        let map: [(String, String)] = [("run", "figure.run"), ("course", "figure.run"), ("jog", "figure.run"), ("footing", "figure.run"),
                                       ("cycl", "figure.outdoor.cycle"), ("bike", "figure.outdoor.cycle"), ("vélo", "figure.outdoor.cycle"),
                                       ("velo", "figure.outdoor.cycle"), ("swim", "figure.pool.swim"), ("natation", "figure.pool.swim"),
                                       ("gym", "dumbbell"), ("muscu", "dumbbell"), ("weight", "dumbbell"), ("yoga", "figure.yoga"),
                                       ("walk", "figure.walk"), ("marche", "figure.walk"), ("hike", "figure.hiking"), ("rando", "figure.hiking"),
                                       ("row", "figure.rower"), ("box", "figure.boxing"), ("tennis", "figure.tennis"), ("foot", "figure.soccer"),
                                       ("basket", "figure.basketball"), ("climb", "figure.climbing"), ("escalade", "figure.climbing")]
        return map.first { s.contains($0.0) }?.1 ?? "figure.mixed.cardio"
    }
}
