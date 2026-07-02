import Foundation
import Combine

/// Single source of truth: entries + all core behavior rules, persisted to a
/// JSON file in Application Support (local only — no sync, no accounts, no network).
final class TimeStore: ObservableObject {
    @Published private(set) var entries: [TimeEntry] = []

    private let fileURL: URL

    /// - Parameter directory: override the storage directory (used by tests).
    init(directory: URL? = nil) {
        let fm = FileManager.default
        let dir: URL
        if let directory {
            dir = directory
        } else {
            let base = (try? fm.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                    appropriateFor: nil, create: true))
                ?? fm.homeDirectoryForCurrentUser
            dir = base.appendingPathComponent("Timekeep", isDirectory: true)
        }
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("entries.json")
        load()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([TimeEntry].self, from: data) {
            entries = decoded
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        if let data = try? encoder.encode(entries) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    // MARK: - Core behavior

    /// Add an entry. Requires non-empty client and hours > 0. The date defaults to
    /// today but may be backdated. Canonicalizes casing against existing clients and
    /// merges same client + same day (keyed on the chosen date).
    /// Returns a transient merge hint when a merge happened, else nil.
    @discardableResult
    func addEntry(client rawClient: String, hours: Double, note rawNote: String,
                  date rawDate: Date = Date()) -> String? {
        let name = rawClient.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, hours > 0 else { return nil }
        let note = rawNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let day = DateHelp.cal.startOfDay(for: rawDate)

        // Canonical casing: reuse existing client's casing on a case-insensitive match.
        let existingName = entries
            .map(\.client)
            .first { $0.compare(name, options: .caseInsensitive) == .orderedSame }
        let client = existingName ?? name

        var hint: String? = nil
        if let idx = entries.firstIndex(where: {
            $0.client == client && DateHelp.cal.isDate($0.date, inSameDayAs: day)
        }) {
            // Merge: add hours, join notes with "; ".
            entries[idx].hours = ((entries[idx].hours + hours) * 100).rounded() / 100
            let joined = [entries[idx].note, note].filter { !$0.isEmpty }.joined(separator: "; ")
            entries[idx].note = joined
            hint = mergeHint(client: client, hours: entries[idx].hours, day: day)
        } else {
            let rounded = (hours * 100).rounded() / 100
            entries.append(TimeEntry(client: client, date: day, hours: rounded, note: note))
        }
        persist()
        return hint
    }

    private func mergeHint(client: String, hours: Double, day: Date) -> String {
        let h = formatHours(hours)
        if DateHelp.cal.isDateInToday(day) {
            return "Merged into today’s \(client) entry — now \(h)."
        }
        return "Merged into \(client) on \(DateHelp.shortDayLabel(day)) — now \(h)."
    }

    /// Edit hours/note/date of an existing entry. Hours must remain > 0 to save.
    /// If the new date lands on a client+day that already has another entry, the two
    /// are merged (hours summed, notes joined) instead of creating a duplicate row.
    @discardableResult
    func updateEntry(id: UUID, hours: Double, note rawNote: String, date rawDate: Date) -> Bool {
        guard hours > 0, let idx = entries.firstIndex(where: { $0.id == id }) else { return false }
        let day = DateHelp.cal.startOfDay(for: rawDate)
        let note = rawNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let client = entries[idx].client
        let roundedHours = (hours * 100).rounded() / 100

        if let targetIdx = entries.firstIndex(where: {
            $0.id != id && $0.client == client && DateHelp.cal.isDate($0.date, inSameDayAs: day)
        }) {
            // Merge into the existing entry for that day, then drop the edited one.
            entries[targetIdx].hours = ((entries[targetIdx].hours + roundedHours) * 100).rounded() / 100
            let joined = [entries[targetIdx].note, note].filter { !$0.isEmpty }.joined(separator: "; ")
            entries[targetIdx].note = joined
            entries.remove(at: idx)
        } else {
            entries[idx].hours = roundedHours
            entries[idx].note = note
            entries[idx].date = day
        }
        persist()
        return true
    }

    func deleteEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        persist()
    }

    // MARK: - Derived data

    func monthTotal(_ monthKey: String) -> Double {
        entries.filter { DateHelp.monthKey($0.date) == monthKey }
            .reduce(0) { $0 + $1.hours }
    }

    /// Subject line for the recap email, e.g. "July 2026 Hours".
    func recapSubject(monthKey: String) -> String {
        "\(DateHelp.monthLabel(fromKey: monthKey)) Hours"
    }

    /// Email body: greeting + the hours content (current view) + signature.
    func recapEmailBody(monthKey: String, byDay: Bool) -> String {
        let month = DateHelp.monthName(fromKey: monthKey)
        let content = recapContent(monthKey: monthKey, byDay: byDay)
        return "Hi,\nhere are my hours for \(month)\n\n\(content)\n\nThanks,\nRahul Gonsalves"
    }

    /// Plain-text recap (Totals view). Kept for callers/tests that don't pass a mode.
    func recapText(monthKey: String) -> String {
        recap(monthKey: monthKey, byDay: false)
    }

    /// Plain-text recap for a calendar month, no notes: the "Time recap — <Month>"
    /// heading followed by the content.
    func recap(monthKey: String, byDay: Bool) -> String {
        "Time recap — \(DateHelp.monthLabel(fromKey: monthKey))\n\n"
            + recapContent(monthKey: monthKey, byDay: byDay)
    }

    /// The recap content without the heading: client lines + total, or the empty
    /// notice. Clients sorted by month total descending. In `byDay` mode each client's
    /// total is broken into its daily entries (days ascending, two-space indent) with a
    /// blank line between clients.
    private func recapContent(monthKey: String, byDay: Bool) -> String {
        let inMonth = entries.filter { DateHelp.monthKey($0.date) == monthKey }
        if inMonth.isEmpty { return "No hours logged." }

        // Aggregate preserving first-seen order (matches the prototype's tie behavior).
        var order: [String] = []
        var byClient: [String: Double] = [:]
        var perDay: [String: [TimeEntry]] = [:]
        for e in inMonth {
            if byClient[e.client] == nil { order.append(e.client) }
            byClient[e.client, default: 0] += e.hours
            perDay[e.client, default: []].append(e)
        }
        let names = order.enumerated().sorted {
            let ha = byClient[$0.element] ?? 0, hb = byClient[$1.element] ?? 0
            if ha != hb { return ha > hb }
            return $0.offset < $1.offset // stable
        }.map(\.element)

        var total: Double = 0
        let blocks = names.map { name -> String in
            let h = byClient[name] ?? 0
            total += h
            var lines = ["\(name) — \(formatHours(h))"]
            if byDay {
                for e in (perDay[name] ?? []).sorted(by: { $0.date < $1.date }) {
                    lines.append("  \(DateHelp.shortDayLabel(e.date)) — \(formatHours(e.hours))")
                }
            }
            return lines.joined(separator: "\n")
        }
        let separator = byDay ? "\n\n" : "\n"
        return blocks.joined(separator: separator) + "\n\nTotal — \(formatHours(total))"
    }

    /// Month keys from the earliest entry to the current month, newest first.
    func monthOptions() -> [String] {
        var keys = Set<String>([DateHelp.monthKey(Date())])
        for e in entries { keys.insert(DateHelp.monthKey(e.date)) }
        return keys.sorted().reversed()
    }
}
