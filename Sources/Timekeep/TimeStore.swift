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

    /// Add an entry. Requires non-empty client and hours > 0. Date is always today.
    /// Canonicalizes casing against existing clients and merges same client + same day.
    /// Returns a transient merge hint when a merge happened, else nil.
    @discardableResult
    func addEntry(client rawClient: String, hours: Double, note rawNote: String) -> String? {
        let name = rawClient.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, hours > 0 else { return nil }
        let note = rawNote.trimmingCharacters(in: .whitespacesAndNewlines)
        let today = DateHelp.cal.startOfDay(for: Date())

        // Canonical casing: reuse existing client's casing on a case-insensitive match.
        let existingName = entries
            .map(\.client)
            .first { $0.compare(name, options: .caseInsensitive) == .orderedSame }
        let client = existingName ?? name

        var hint: String? = nil
        if let idx = entries.firstIndex(where: {
            $0.client == client && DateHelp.cal.isDate($0.date, inSameDayAs: today)
        }) {
            // Merge: add hours, join notes with "; ".
            entries[idx].hours = ((entries[idx].hours + hours) * 100).rounded() / 100
            let joined = [entries[idx].note, note].filter { !$0.isEmpty }.joined(separator: "; ")
            entries[idx].note = joined
            hint = "Merged into today’s \(client) entry — now \(formatHours(entries[idx].hours))."
        } else {
            let rounded = (hours * 100).rounded() / 100
            entries.append(TimeEntry(client: client, date: today, hours: rounded, note: note))
        }
        persist()
        return hint
    }

    /// Edit hours/note of an existing entry. Hours must remain > 0 to save.
    @discardableResult
    func updateEntry(id: UUID, hours: Double, note: String) -> Bool {
        guard hours > 0, let idx = entries.firstIndex(where: { $0.id == id }) else { return false }
        entries[idx].hours = (hours * 100).rounded() / 100
        entries[idx].note = note.trimmingCharacters(in: .whitespacesAndNewlines)
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

    /// Plain-text recap for a calendar month, clients sorted by hours desc, no notes.
    func recapText(monthKey: String) -> String {
        let label = DateHelp.monthLabel(fromKey: monthKey)
        let inMonth = entries.filter { DateHelp.monthKey($0.date) == monthKey }
        if inMonth.isEmpty {
            return "Time recap — \(label)\n\nNo hours logged."
        }
        // Aggregate preserving first-seen order (matches the prototype's tie behavior).
        var order: [String] = []
        var byClient: [String: Double] = [:]
        for e in inMonth {
            if byClient[e.client] == nil { order.append(e.client) }
            byClient[e.client, default: 0] += e.hours
        }
        let names = order.enumerated().sorted {
            let ha = byClient[$0.element] ?? 0, hb = byClient[$1.element] ?? 0
            if ha != hb { return ha > hb }
            return $0.offset < $1.offset // stable
        }.map(\.element)

        var total: Double = 0
        let lines = names.map { name -> String in
            let h = byClient[name] ?? 0
            total += h
            return "\(name) — \(formatHours(h))"
        }
        return "Time recap — \(label)\n\n" + lines.joined(separator: "\n") + "\n\nTotal — \(formatHours(total))"
    }

    /// Month keys from the earliest entry to the current month, newest first.
    func monthOptions() -> [String] {
        var keys = Set<String>([DateHelp.monthKey(Date())])
        for e in entries { keys.insert(DateHelp.monthKey(e.date)) }
        return keys.sorted().reversed()
    }
}
