import Foundation
import UserNotifications

@MainActor
final class PortfolioNotificationScheduler: ObservableObject, ReminderScheduler {
    static let shared = PortfolioNotificationScheduler()

    private let weekendIdentifier = "portfolio.weekend.reminder"
    private let staleIdentifier = "portfolio.stale.daily.reminder"
    private let scheduledPrefix = "portfolio.scheduled."
    var isWeekendReminderEnabled = true

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func refreshSchedules(lastStatusUpdate: Date, now: Date = .now) {
        refreshSchedules(lastStatusUpdate: lastStatusUpdate, scheduledItems: [], now: now)
    }

    func refreshSchedules(lastStatusUpdate: Date, scheduledItems: [ScheduledItem], now: Date = .now) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        if isWeekendReminderEnabled {
            let weekendContent = UNMutableNotificationContent()
            weekendContent.title = "Portfolio weekly check-in"
            weekendContent.body = "Update your balances to keep net worth and projections accurate."
            weekendContent.sound = .default

            var weekendComponents = DateComponents()
            weekendComponents.weekday = 1
            weekendComponents.hour = 21
            weekendComponents.minute = 0

            let weekendTrigger = UNCalendarNotificationTrigger(dateMatching: weekendComponents, repeats: true)
            let weekendRequest = UNNotificationRequest(identifier: weekendIdentifier, content: weekendContent, trigger: weekendTrigger)
            center.add(weekendRequest)
        }

        if Self.shouldScheduleDailyEscalation(lastStatusUpdate: lastStatusUpdate, now: now) {
            let staleContent = UNMutableNotificationContent()
            staleContent.title = "Portfolio update overdue"
            staleContent.body = "You have not updated financial status in 7+ days. Update today."
            staleContent.sound = .default

            var staleComponents = DateComponents()
            staleComponents.hour = 21
            staleComponents.minute = 0

            let staleTrigger = UNCalendarNotificationTrigger(dateMatching: staleComponents, repeats: true)
            let staleRequest = UNNotificationRequest(identifier: staleIdentifier, content: staleContent, trigger: staleTrigger)
            center.add(staleRequest)
        }

        for item in scheduledItems.filter(\.isActive) {
            scheduleNotifications(for: item, now: now, center: center)
        }
    }

    static func shouldScheduleDailyEscalation(lastStatusUpdate: Date, now: Date) -> Bool {
        let oneWeek: TimeInterval = 7 * 24 * 60 * 60
        return now.timeIntervalSince(lastStatusUpdate) >= oneWeek
    }

    private func scheduleNotifications(for item: ScheduledItem, now: Date, center: UNUserNotificationCenter) {
        let nextOccurrences = ScheduleEngine.upcomingOccurrences(for: item, after: now, count: 2)

        for dueDate in nextOccurrences {
            let dueIdentifier = "\(scheduledPrefix)\(item.id.uuidString).due.\(Int(dueDate.timeIntervalSince1970))"
            let dueContent = UNMutableNotificationContent()
            dueContent.title = "\(item.title) due today"
            dueContent.body = notificationBody(for: item, isAdvanceNotice: false)
            dueContent.sound = .default

            let dueTrigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate),
                repeats: false
            )
            center.add(UNNotificationRequest(identifier: dueIdentifier, content: dueContent, trigger: dueTrigger))

            guard item.remindDaysBefore > 0,
                  let advanceDate = Calendar.current.date(byAdding: .day, value: -item.remindDaysBefore, to: dueDate),
                  advanceDate > now else {
                continue
            }

            let advanceIdentifier = "\(scheduledPrefix)\(item.id.uuidString).advance.\(Int(advanceDate.timeIntervalSince1970))"
            let advanceContent = UNMutableNotificationContent()
            advanceContent.title = "\(item.title) coming up"
            advanceContent.body = notificationBody(for: item, isAdvanceNotice: true)
            advanceContent.sound = .default

            let advanceTrigger = UNCalendarNotificationTrigger(
                dateMatching: Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: advanceDate),
                repeats: false
            )
            center.add(UNNotificationRequest(identifier: advanceIdentifier, content: advanceContent, trigger: advanceTrigger))
        }
    }

    private func notificationBody(for item: ScheduledItem, isAdvanceNotice: Bool) -> String {
        let prefix = isAdvanceNotice ? "Reminder:" : "Due now:"
        if item.kind == .bill {
            let amountText = PortfolioFormatters.currency(item.amount, code: item.currency)
            return "\(prefix) \(item.category.displayName) \(amountText)."
        }
        return "\(prefix) \(item.category.displayName)."
    }
}
