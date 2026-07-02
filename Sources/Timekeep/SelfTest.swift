import Foundation

/// Runnable via `Timekeep --selftest` — exercises the real store/formatting code
/// so behavior can be verified from the command line without the UI.
enum SelfTest {
    static func run() -> Never {
        var failures = 0
        func check(_ label: String, _ got: String, _ want: String) {
            let ok = got == want
            if !ok { failures += 1 }
            print("\(ok ? "✓" : "✗") \(label): \(ok ? "" : "got [\(got)] want [\(want)]")")
        }

        // formatHours
        check("fmt 5",    formatHours(5),    "5h")
        check("fmt 2.5",  formatHours(2.5),  "2.5h")
        check("fmt 0.75", formatHours(0.75), "0.75h")
        check("fmt 42.5", formatHours(42.5), "42.5h")
        check("fmt round up",   formatHours(5.128), "5.13h") // rounds to 2 decimals
        check("fmt round down", formatHours(1.001), "1h")

        // Store behavior in an isolated temp dir.
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("timekeep-selftest-\(UUID().uuidString)")
        let store = TimeStore(directory: dir)

        // Canonicalization: "Acme Co" exists → "acme co" logs to "Acme Co".
        _ = store.addEntry(client: "Acme Co", hours: 3, note: "kickoff")
        let hint = store.addEntry(client: "acme co", hours: 2, note: "call")
        check("canonical merge count", "\(store.entries.count)", "1")
        check("merge hours", formatHours(store.entries[0].hours), "5h")
        check("merge notes", store.entries[0].note, "kickoff; call")
        check("merge hint", hint ?? "nil", "Merged into today’s Acme Co entry — now 5h.")

        // Reject invalid input.
        _ = store.addEntry(client: "", hours: 4, note: "")
        _ = store.addEntry(client: "Beta LLC", hours: 0, note: "")
        check("reject invalid", "\(store.entries.count)", "1")

        // A second client, current month.
        _ = store.addEntry(client: "Beta LLC", hours: 12.5, note: "")
        let key = DateHelp.monthKey(Date())
        let recap = store.recapText(monthKey: key)
        let label = DateHelp.monthLabel(fromKey: key)
        let expected = "Time recap — \(label)\n\nBeta LLC — 12.5h\nAcme Co — 5h\n\nTotal — 17.5h"
        check("recap sorted desc", recap, expected)

        // Empty month recap.
        let emptyKey = "1999-01"
        check("empty recap",
              store.recapText(monthKey: emptyKey),
              "Time recap — January 1999\n\nNo hours logged.")

        // Persistence round-trip.
        let reloaded = TimeStore(directory: dir)
        check("persist reload count", "\(reloaded.entries.count)", "2")

        try? FileManager.default.removeItem(at: dir)

        // --- Backdated entries ---
        let cal = DateHelp.cal
        let today = cal.startOfDay(for: Date())
        let yesterday = cal.date(byAdding: .day, value: -1, to: today)!

        // Backdated add lands in the chosen day's month; merge keys on that date and
        // the hint names the day when it isn't today.
        let bdir = FileManager.default.temporaryDirectory
            .appendingPathComponent("timekeep-selftest-\(UUID().uuidString)")
        let bstore = TimeStore(directory: bdir)
        _ = bstore.addEntry(client: "Beta", hours: 1, note: "x", date: yesterday)
        let bHint = bstore.addEntry(client: "beta", hours: 4, note: "y", date: yesterday)
        check("backdate merge count", "\(bstore.entries.count)", "1")
        check("backdate lands in day", DateHelp.monthKey(bstore.entries[0].date), DateHelp.monthKey(yesterday))
        check("backdate hint names day", bHint ?? "nil",
              "Merged into Beta on \(DateHelp.shortDayLabel(yesterday)) — now 5h.")

        // Editing an entry's date onto an existing client+day merges the two rows.
        _ = bstore.addEntry(client: "Beta", hours: 3, note: "today", date: today)
        check("pre-edit count", "\(bstore.entries.count)", "2")
        let todayEntry = bstore.entries.first { cal.isDate($0.date, inSameDayAs: today) }!
        _ = bstore.updateEntry(id: todayEntry.id, hours: todayEntry.hours,
                               note: todayEntry.note, date: yesterday)
        check("edit-merge count", "\(bstore.entries.count)", "1")
        check("edit-merge hours", formatHours(bstore.entries[0].hours), "8h")
        check("edit-merge notes", bstore.entries[0].note, "x; y; today")

        try? FileManager.default.removeItem(at: bdir)

        // --- Recap email draft ---
        check("recap subject", bstore.recapSubject(monthKey: DateHelp.monthKey(yesterday)),
              "Time recap — \(DateHelp.monthLabel(fromKey: DateHelp.monthKey(yesterday)))")

        let mailto = MailDraft.mailtoURL(subject: "Time recap — July 2026",
                                         body: "Acme Co — 5h\n\nTotal — 5h")!.absoluteString
        func has(_ needle: String) -> String { mailto.contains(needle) ? "y" : "n" }
        func lacks(_ needle: String) -> String { mailto.contains(needle) ? "n" : "y" }
        check("mailto empty To",   has("mailto:?subject="), "y")
        check("mailto CRLF",       has("%0D%0A"),           "y") // newlines encoded as CRLF
        check("mailto em-dash",    has("%E2%80%94"),        "y") // — survives as UTF-8
        check("mailto space",      has("%20"),              "y")
        check("mailto no raw dash", lacks("—"),             "y")
        check("mailto no raw LF",   lacks("\n"),            "y")

        print(failures == 0 ? "\nALL PASS" : "\n\(failures) FAILURE(S)")
        exit(failures == 0 ? 0 : 1)
    }
}
