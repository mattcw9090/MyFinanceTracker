import Foundation

enum Weekday {
    /// Monday–Sunday, in the order this app uses everywhere.
    static let allNames = [
        "Monday", "Tuesday", "Wednesday", "Thursday",
        "Friday", "Saturday", "Sunday"
    ]

    /// Today's weekday name (e.g. "Wednesday"), used to default day pickers.
    static var today: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEEE"
        return formatter.string(from: Date())
    }
}

/// Monday-based weeks in Australia/Perth. Perth has no daylight saving, so a
/// calendar date stays on that date when formatted here.
enum PerthWeek {
    static let timeZone = TimeZone(identifier: "Australia/Perth")!

    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = Locale(identifier: "en_AU")
        calendar.firstWeekday = 2
        return calendar
    }

    static func monday(containing date: Date) -> Date {
        let calendar = calendar
        let weekday = calendar.component(.weekday, from: date)
        let daysFromMonday = (weekday + 5) % 7
        let shifted = calendar.date(byAdding: .day, value: -daysFromMonday, to: date) ?? date
        return calendar.startOfDay(for: shifted)
    }

    static func addingWeeks(_ weeks: Int, to monday: Date) -> Date {
        calendar.date(byAdding: .day, value: weeks * 7, to: monday) ?? monday
    }

    /// `yyyy-MM-dd` for the Perth calendar day. Use this for week-start
    /// arguments. Stored coaching dates use `SupabaseTimestamp.formatDateOnly`.
    static func dateOnlyString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    static func label(for monday: Date) -> String {
        let calendar = calendar
        let sunday = calendar.date(byAdding: .day, value: 6, to: monday) ?? monday
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_AU")
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("d MMM")
        let year = calendar.component(.year, from: sunday)
        return "\(formatter.string(from: monday)) – \(formatter.string(from: sunday)) \(year)"
    }
}

/// Current Perth week when it has any sessions, otherwise the next week that
/// does. Does not look backward. An empty search stays on the current Monday.
func defaultCoachingWeekStart<Rows: Collection>(
    currentMonday: Date,
    searchLimit: Int = 16,
    sessions: (Date) async throws -> Rows
) async rethrows -> (week: Date, rows: Rows) {
    let current = try await sessions(currentMonday)
    if !current.isEmpty {
        return (currentMonday, current)
    }
    guard searchLimit > 0 else { return (currentMonday, current) }
    for offset in 1...searchLimit {
        let next = PerthWeek.addingWeeks(offset, to: currentMonday)
        let rows = try await sessions(next)
        if !rows.isEmpty {
            return (next, rows)
        }
    }
    return (currentMonday, current)
}
