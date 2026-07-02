import Foundation

/// Hours formatting used everywhere: round to 2 decimals, drop trailing decimals
/// for whole numbers, suffix `h`  →  `5h`, `2.5h`, `0.75h`.
func formatHours(_ h: Double) -> String {
    let r = (h * 100).rounded() / 100
    if r == r.rounded() {
        return "\(Int(r))h"
    }
    var s = String(format: "%.2f", r)
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    return s + "h"
}

enum DateHelp {
    static let cal = Calendar.current

    /// "yyyy-MM" key for a date, in the current calendar.
    static func monthKey(_ date: Date) -> String {
        let c = cal.dateComponents([.year, .month], from: date)
        return String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
    }

    /// First day of the month for a "yyyy-MM" key.
    static func date(fromMonthKey key: String) -> Date {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 2 else { return Date() }
        return cal.date(from: DateComponents(year: parts[0], month: parts[1], day: 1)) ?? Date()
    }

    private static func fmt(_ template: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = template
        return f
    }

    /// e.g. "Wednesday, July 2, 2026"
    static func todayLabel(_ date: Date = Date()) -> String {
        fmt("EEEE, MMMM d, yyyy").string(from: date)
    }

    /// e.g. "July 2026"
    static func monthLabel(_ date: Date) -> String {
        fmt("MMMM yyyy").string(from: date)
    }

    static func monthLabel(fromKey key: String) -> String {
        monthLabel(date(fromMonthKey: key))
    }

    /// e.g. "Wed, Jul 2"; year appended only when not the current year.
    static func dayLabel(_ date: Date, now: Date = Date()) -> String {
        let sameYear = cal.component(.year, from: date) == cal.component(.year, from: now)
        return fmt(sameYear ? "EEE, MMM d" : "EEE, MMM d, yyyy").string(from: date)
    }
}
