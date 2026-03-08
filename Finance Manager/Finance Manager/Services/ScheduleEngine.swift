import Foundation

enum ScheduleEngine {
    static func nextOccurrence(for item: ScheduledItem, after date: Date, calendar: Calendar = .current) -> Date? {
        guard item.isActive else { return nil }

        let anchor = item.startDate
        if item.recurrence == .oneTime {
            return anchor > date ? anchor : nil
        }

        if anchor > date {
            return anchor
        }

        switch item.recurrence {
        case .weekly:
            return advanceByFixedInterval(start: anchor, after: date, dayInterval: 7, calendar: calendar)
        case .biweekly:
            return advanceByFixedInterval(start: anchor, after: date, dayInterval: 14, calendar: calendar)
        case .monthly:
            return advanceByMonthInterval(start: anchor, after: date, monthInterval: 1, calendar: calendar)
        case .quarterly:
            return advanceByMonthInterval(start: anchor, after: date, monthInterval: 3, calendar: calendar)
        case .yearly:
            return advanceByMonthInterval(start: anchor, after: date, monthInterval: 12, calendar: calendar)
        case .oneTime:
            return nil
        }
    }

    static func upcomingOccurrences(
        for item: ScheduledItem,
        after date: Date,
        count: Int,
        calendar: Calendar = .current
    ) -> [Date] {
        guard count > 0 else { return [] }

        var values: [Date] = []
        var cursor = date

        while values.count < count {
            guard let next = nextOccurrence(for: item, after: cursor, calendar: calendar) else { break }
            values.append(next)
            cursor = next.addingTimeInterval(1)
        }

        return values
    }

    private static func advanceByFixedInterval(
        start: Date,
        after date: Date,
        dayInterval: Int,
        calendar: Calendar
    ) -> Date? {
        let days = calendar.dateComponents([.day], from: start, to: date).day ?? 0
        let cycles = max(Int(floor(Double(days) / Double(dayInterval))) + 1, 1)
        return calendar.date(byAdding: .day, value: cycles * dayInterval, to: start)
    }

    private static func advanceByMonthInterval(
        start: Date,
        after date: Date,
        monthInterval: Int,
        calendar: Calendar
    ) -> Date? {
        let monthsBetween = calendar.dateComponents([.month], from: start, to: date).month ?? 0
        let cycles = max((monthsBetween / monthInterval) + 1, 1)
        let monthOffset = cycles * monthInterval
        return calendar.date(byAdding: .month, value: monthOffset, to: start)
    }
}
