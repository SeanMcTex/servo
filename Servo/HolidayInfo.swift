import Foundation

struct HolidayInfo {
    let name: String
    let daysUntil: Int  // 0 = today

    nonisolated var contextString: String {
        daysUntil == 0 ? "Today: \(name)" : "Upcoming: \(name) (\(daysUntil)d)"
    }

    /// Returns the nearest holiday within `lookaheadDays` days (default 7), or nil.
    nonisolated static func current(lookaheadDays: Int = 7) -> HolidayInfo? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for dayOffset in 0...lookaheadDays {
            guard let candidate = calendar.date(byAdding: .day, value: dayOffset, to: today) else { continue }
            let comps = calendar.dateComponents([.year, .month, .day], from: candidate)
            guard let year = comps.year, let month = comps.month, let day = comps.day else { continue }

            for h in fixedHolidays where h.month == month && h.day == day {
                return HolidayInfo(name: h.name, daysUntil: dayOffset)
            }

            for h in floatingHolidays where h.year == year && h.month == month && h.day == day {
                return HolidayInfo(name: h.name, daysUntil: dayOffset)
            }
        }
        return nil
    }
}

// MARK: - Holiday data
// Fixed holidays repeat every year by month/day — no maintenance required.
// Floating holidays are hardcoded through 2030. See CLAUDE.md for update instructions.

private struct FixedHoliday: Sendable { let month: Int; let day: Int; let name: String }
private struct FloatingHoliday: Sendable { let year: Int; let month: Int; let day: Int; let name: String }

private extension HolidayInfo {
    nonisolated static let fixedHolidays: [FixedHoliday] = [
        FixedHoliday(month: 1,  day: 1,  name: "New Year's Day"),
        FixedHoliday(month: 7,  day: 4,  name: "Independence Day"),
        FixedHoliday(month: 10, day: 31, name: "Halloween"),
        FixedHoliday(month: 11, day: 11, name: "Veterans Day"),
        FixedHoliday(month: 12, day: 24, name: "Christmas Eve"),
        FixedHoliday(month: 12, day: 25, name: "Christmas"),
        FixedHoliday(month: 12, day: 31, name: "New Year's Eve"),
    ]

    nonisolated static let floatingHolidays: [FloatingHoliday] = [
    // MLK Day (3rd Monday of January)
    FloatingHoliday(year: 2026, month: 1,  day: 19, name: "MLK Day"),
    FloatingHoliday(year: 2027, month: 1,  day: 18, name: "MLK Day"),
    FloatingHoliday(year: 2028, month: 1,  day: 17, name: "MLK Day"),
    FloatingHoliday(year: 2029, month: 1,  day: 15, name: "MLK Day"),
    FloatingHoliday(year: 2030, month: 1,  day: 21, name: "MLK Day"),
    // Presidents Day (3rd Monday of February)
    FloatingHoliday(year: 2026, month: 2,  day: 16, name: "Presidents Day"),
    FloatingHoliday(year: 2027, month: 2,  day: 15, name: "Presidents Day"),
    FloatingHoliday(year: 2028, month: 2,  day: 21, name: "Presidents Day"),
    FloatingHoliday(year: 2029, month: 2,  day: 19, name: "Presidents Day"),
    FloatingHoliday(year: 2030, month: 2,  day: 18, name: "Presidents Day"),
    // Easter (dates via Anonymous Gregorian algorithm)
    FloatingHoliday(year: 2026, month: 4,  day: 5,  name: "Easter"),
    FloatingHoliday(year: 2027, month: 3,  day: 28, name: "Easter"),
    FloatingHoliday(year: 2028, month: 4,  day: 16, name: "Easter"),
    FloatingHoliday(year: 2029, month: 4,  day: 1,  name: "Easter"),
    FloatingHoliday(year: 2030, month: 4,  day: 21, name: "Easter"),
    // Memorial Day (last Monday of May)
    FloatingHoliday(year: 2026, month: 5,  day: 25, name: "Memorial Day"),
    FloatingHoliday(year: 2027, month: 5,  day: 31, name: "Memorial Day"),
    FloatingHoliday(year: 2028, month: 5,  day: 29, name: "Memorial Day"),
    FloatingHoliday(year: 2029, month: 5,  day: 28, name: "Memorial Day"),
    FloatingHoliday(year: 2030, month: 5,  day: 27, name: "Memorial Day"),
    // Labor Day (1st Monday of September)
    FloatingHoliday(year: 2026, month: 9,  day: 7,  name: "Labor Day"),
    FloatingHoliday(year: 2027, month: 9,  day: 6,  name: "Labor Day"),
    FloatingHoliday(year: 2028, month: 9,  day: 4,  name: "Labor Day"),
    FloatingHoliday(year: 2029, month: 9,  day: 3,  name: "Labor Day"),
    FloatingHoliday(year: 2030, month: 9,  day: 2,  name: "Labor Day"),
    // Columbus Day (2nd Monday of October)
    FloatingHoliday(year: 2026, month: 10, day: 12, name: "Columbus Day"),
    FloatingHoliday(year: 2027, month: 10, day: 11, name: "Columbus Day"),
    FloatingHoliday(year: 2028, month: 10, day: 9,  name: "Columbus Day"),
    FloatingHoliday(year: 2029, month: 10, day: 8,  name: "Columbus Day"),
    FloatingHoliday(year: 2030, month: 10, day: 14, name: "Columbus Day"),
    // Thanksgiving (4th Thursday of November)
    FloatingHoliday(year: 2026, month: 11, day: 26, name: "Thanksgiving"),
    FloatingHoliday(year: 2027, month: 11, day: 25, name: "Thanksgiving"),
    FloatingHoliday(year: 2028, month: 11, day: 23, name: "Thanksgiving"),
    FloatingHoliday(year: 2029, month: 11, day: 22, name: "Thanksgiving"),
    FloatingHoliday(year: 2030, month: 11, day: 28, name: "Thanksgiving"),
    ]
}
