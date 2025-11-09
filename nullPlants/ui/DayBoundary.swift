import Foundation

public enum DayBoundary {
    /// UserDefaults keys
    private static let hourKey = "settings.dayBoundaryHour"
    private static let minuteKey = "settings.dayBoundaryMinute"

    /// Returns the configured boundary components (hour, minute). Defaults to 8:00 if not set.
    public static func configuredComponents() -> DateComponents {
        let ud = UserDefaults.standard
        let hour = ud.object(forKey: hourKey) as? Int ?? 8
        let minute = ud.object(forKey: minuteKey) as? Int ?? 0
        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        return comps
    }

    /// Stores the configured boundary time.
    public static func set(hour: Int, minute: Int) {
        let ud = UserDefaults.standard
        ud.set(hour, forKey: hourKey)
        ud.set(minute, forKey: minuteKey)
    }

    /// Returns true if two dates fall in the same custom day bucket defined by the boundary time.
    public static func isInSameCustomDay(_ d1: Date, _ d2: Date, calendar: Calendar = .current) -> Bool {
        return customDayStart(for: d1, calendar: calendar) == customDayStart(for: d2, calendar: calendar)
    }

    /// Returns true if the given date is in the current custom day bucket relative to now.
    public static func isInTodayCustom(_ date: Date, calendar: Calendar = .current) -> Bool {
        return isInSameCustomDay(date, Date(), calendar: calendar)
    }

    /// Computes the start Date of the custom day bucket that contains the given date.
    public static func customDayStart(for date: Date, calendar: Calendar = .current) -> Date {
        let comps = configuredComponents()
        let hour = comps.hour ?? 8
        let minute = comps.minute ?? 0

        // Build the boundary for the calendar day of `date` at configured time in the same time zone.
        var dayStartComps = calendar.dateComponents([.year, .month, .day], from: date)
        dayStartComps.hour = hour
        dayStartComps.minute = minute
        dayStartComps.second = 0

        let boundaryToday = calendar.date(from: dayStartComps) ?? date

        if date >= boundaryToday {
            // Same-day boundary
            return boundaryToday
        } else {
            // Boundary was earlier today, so the bucket started yesterday at boundary time
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: boundaryToday) else { return boundaryToday }
            return previousDay
        }
    }
}
