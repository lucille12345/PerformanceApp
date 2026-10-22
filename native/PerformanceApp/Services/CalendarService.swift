import EventKit
import Foundation
import Observation

struct CalendarEvent: Identifiable, Hashable {
    var id: String
    var title: String
    var start: Date
    var allDay: Bool
    var color: CGColor?
}

/// Reads today's events from the Calendar app (and every account added to it).
@MainActor @Observable
final class CalendarService {
    @ObservationIgnored private let store = EKEventStore()
    private(set) var events: [CalendarEvent] = []
    private(set) var denied = false

    func refresh() async {
        let granted = (try? await store.requestFullAccessToEvents()) ?? false
        denied = !granted
        guard granted else { events = []; return }
        let start = Calendar.current.startOfDay(for: Date())
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        events = store.events(matching: predicate)
            .sorted { ($0.isAllDay ? 0 : 1, $0.startDate) < ($1.isAllDay ? 0 : 1, $1.startDate) }
            .map { CalendarEvent(id: $0.eventIdentifier ?? UUID().uuidString, title: $0.title ?? "", start: $0.startDate,
                                 allDay: $0.isAllDay, color: $0.calendar?.cgColor) }
    }

    /// Opens the Calendar app on that event (iPhone: on its day).
    func url(for event: CalendarEvent?) -> URL {
        #if os(iOS)
        let date = event?.start ?? Date()
        return URL(string: "calshow:\(Int(date.timeIntervalSinceReferenceDate))")!
        #else
        if let id = event?.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
           let url = URL(string: "ical://ekevent/\(id)?method=show&options=more") { return url }
        return URL(fileURLWithPath: "/System/Applications/Calendar.app")
        #endif
    }
}
