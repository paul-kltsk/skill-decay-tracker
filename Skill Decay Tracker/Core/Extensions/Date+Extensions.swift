import Foundation

extension Date {

    // MARK: - Day Arithmetic

    /// Number of full days elapsed between this date and now.
    ///
    /// Returns 0 if the date is in the future.
    var daysSinceNow: Double {
        max(0, Date.now.timeIntervalSince(self) / 86_400)
    }

    /// Returns a new `Date` by adding the given number of days.
    func addingDays(_ days: Double) -> Date {
        addingTimeInterval(days * 86_400)
    }

    // MARK: - Relative Formatting

    /// Short human-readable string relative to today.
    ///
    /// Examples: "Today", "Yesterday", "3 days ago", "2 weeks ago"
    var relativeString: String {
        let days = Int(daysSinceNow)
        switch days {
        case 0:       return String(localized: "Today")
        case 1:       return String(localized: "Yesterday")
        case 2...6:   return String(localized: "\(days) days ago")
        case 7...13:  return String(localized: "1 week ago")
        case 14...29: return String(localized: "\(days / 7) weeks ago")
        default:
            return formatted(.dateTime.month(.abbreviated).day())
        }
    }

    /// Short date string: "Mar 16".
    var shortDateString: String {
        formatted(.dateTime.month(.abbreviated).day())
    }

    /// Medium date string: "Mar 16, 2026".
    var mediumDateString: String {
        formatted(.dateTime.month(.abbreviated).day().year())
    }

    // MARK: - Calendar Helpers

    /// Returns `true` if the date falls on today (same calendar day in the current locale).
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Returns `true` if the date falls on yesterday.
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }

    /// Start of the calendar day (midnight) for this date in the current time zone.
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    /// Number of full calendar days between this date and another.
    func calendarDays(from other: Date) -> Int {
        let from = Calendar.current.startOfDay(for: other)
        let to   = Calendar.current.startOfDay(for: self)
        return Calendar.current.dateComponents([.day], from: from, to: to).day ?? 0
    }
}
