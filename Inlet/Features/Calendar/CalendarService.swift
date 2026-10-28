import EventKit
import SwiftUI

struct CalendarEvent: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let color: Color
}

/// Today's remaining events, plus a heads-up shortly before each one starts.
@MainActor
final class CalendarService: ObservableObject {
    @Published private(set) var events: [CalendarEvent] = []
    @Published private(set) var status: EKAuthorizationStatus = EKEventStore.authorizationStatus(for: .event)

    var onUpcoming: ((CalendarEvent) -> Void)?

    private let store = EKEventStore()
    private var timer: Timer?
    private var observer: NSObjectProtocol?
    private var notified: Set<String> = []

    static let leadTime: TimeInterval = 5 * 60

    var isAuthorized: Bool { status == .fullAccess }

    func start() {
        guard timer == nil else { return }
        refresh()
        observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer.tolerance = 5
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
    }

    #if DEBUG
    func injectPreview(_ events: [CalendarEvent]) {
        self.events = events
        self.status = .fullAccess
    }
    #endif

    func requestAccess() {
        Task {
            _ = try? await store.requestFullAccessToEvents()
            status = EKEventStore.authorizationStatus(for: .event)
            refresh()
        }
    }

    func openCalendarApp() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: url, configuration: .init())
        }
    }

    private func refresh() {
        status = EKEventStore.authorizationStatus(for: .event)
        guard isAuthorized else {
            events = []
            return
        }

        let now = Date()
        let endOfDay = Calendar.current.startOfDay(for: now).addingTimeInterval(24 * 3600)
        let predicate = store.predicateForEvents(withStart: now, end: endOfDay, calendars: nil)
        events = store.events(matching: predicate)
            .filter { $0.endDate > now }
            .sorted { ($0.isAllDay ? 0 : 1, $0.startDate) < ($1.isAllDay ? 0 : 1, $1.startDate) }
            .map {
                CalendarEvent(id: $0.eventIdentifier ?? UUID().uuidString,
                              title: $0.title ?? String(localized: "Event"),
                              start: $0.startDate,
                              end: $0.endDate,
                              isAllDay: $0.isAllDay,
                              color: Color(nsColor: $0.calendar?.color ?? .systemBlue))
            }

        for event in events where !event.isAllDay && !notified.contains(event.id) {
            let until = event.start.timeIntervalSince(now)
            if until > 0 && until <= Self.leadTime {
                notified.insert(event.id)
                onUpcoming?(event)
            }
        }
    }
}
