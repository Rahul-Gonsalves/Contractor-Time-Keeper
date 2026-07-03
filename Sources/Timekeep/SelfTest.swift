import Foundation

/// Runnable via `Timekeep --selftest` — exercises the real store/formatting code
/// so behavior can be verified from the command line without the UI.
enum SelfTest {
    /// `Timekeep --xlsx <path> [--byday]` — writes a sample workbook for validation.
    static func writeSampleXLSX(path: String, byDay: Bool) -> Never {
        let cal = DateHelp.cal
        let mc = cal.dateComponents([.year, .month], from: Date())
        func day(_ d: Int) -> Date { cal.date(from: DateComponents(year: mc.year, month: mc.month, day: d))! }
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("xlsx-sample-\(UUID().uuidString)")
        let store = TimeStore(directory: dir)
        _ = store.addEntry(client: "Acme Co", hours: 2, note: "", date: day(1))
        _ = store.addEntry(client: "Acme Co", hours: 3.5, note: "", date: day(2))
        _ = store.addEntry(client: "Acme Co", hours: 6, note: "", date: day(8))
        _ = store.addEntry(client: "Beta LLC", hours: 4, note: "", date: day(2))
        _ = store.addEntry(client: "Beta LLC", hours: 8, note: "", date: day(8))
        let mk = DateHelp.monthKey(Date())
        XLSXExport.write(to: URL(fileURLWithPath: path),
                         monthLabel: DateHelp.monthLabel(fromKey: mk),
                         clients: store.aggregate(monthKey: mk),
                         byDay: byDay)
        try? FileManager.default.removeItem(at: dir)
        print("wrote \(path)")
        exit(0)
    }

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

        check("money whole",  formatMoney(340),    "$340")
        check("money cents",  formatMoney(347.5),  "$347.50")
        check("money round",  formatMoney(347.529), "$347.53")

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
        let mkY = DateHelp.monthKey(yesterday)
        check("recap subject", bstore.recapSubject(monthKey: mkY),
              "\(DateHelp.monthLabel(fromKey: mkY)) Hours")

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

        let withTo = MailDraft.mailtoURL(subject: "S", body: "B", to: " boss+recap@acme.co ")!.absoluteString
        check("mailto to prefix", withTo.hasPrefix("mailto:boss+recap@acme.co?") ? "y" : "n", "y")

        // --- Recap "By day" breakdown ---
        let ddir = FileManager.default.temporaryDirectory
            .appendingPathComponent("timekeep-selftest-\(UUID().uuidString)")
        let dstore = TimeStore(directory: ddir)
        let mc = cal.dateComponents([.year, .month], from: Date())
        let d5 = cal.date(from: DateComponents(year: mc.year, month: mc.month, day: 5))!
        let d10 = cal.date(from: DateComponents(year: mc.year, month: mc.month, day: 10))!
        _ = dstore.addEntry(client: "Acme", hours: 2, note: "", date: d5)
        _ = dstore.addEntry(client: "Acme", hours: 3.5, note: "", date: d10)
        _ = dstore.addEntry(client: "Beta", hours: 4, note: "", date: d5)
        let mk = DateHelp.monthKey(Date())
        let lbl = DateHelp.monthLabel(fromKey: mk)

        let expectedTotals = [
            "Time recap — \(lbl)", "", "Acme — 5.5h", "Beta — 4h", "", "Total — 9.5h",
        ].joined(separator: "\n")
        check("recap totals", dstore.recap(monthKey: mk, byDay: false), expectedTotals)

        let expectedByDay = [
            "Time recap — \(lbl)",
            "",
            "Acme — 5.5h",
            "  \(DateHelp.shortDayLabel(d5)) — 2h",
            "  \(DateHelp.shortDayLabel(d10)) — 3.5h",
            "",
            "Beta — 4h",
            "  \(DateHelp.shortDayLabel(d5)) — 4h",
            "",
            "Total — 9.5h",
        ].joined(separator: "\n")
        check("recap by day", dstore.recap(monthKey: mk, byDay: true), expectedByDay)

        // Email body: greeting + hours content (no heading) + signature.
        let expectedEmail = [
            "Hi,",
            "here are my hours for \(DateHelp.monthName(fromKey: mk))",
            "",
            "Acme — 5.5h",
            "Beta — 4h",
            "",
            "Total — 9.5h",
            "",
            "Thanks,",
            "Rahul Gonsalves",
        ].joined(separator: "\n")
        check("recap email body", dstore.recapEmailBody(monthKey: mk, byDay: false), expectedEmail)
        check("recap email subject", dstore.recapSubject(monthKey: mk),
              "\(DateHelp.monthLabel(fromKey: mk)) Hours")

        // --- HTML recap ---
        func yesIf(_ b: Bool) -> String { b ? "y" : "n" }
        let htmlTotals = dstore.recapHTML(monthKey: mk, byDay: false)
        check("html heading",       yesIf(htmlTotals.contains("Time recap — \(lbl)")), "y")
        check("html table",         yesIf(htmlTotals.contains("<table")), "y")
        check("html header bg",     yesIf(htmlTotals.contains("#F1F4F8")), "y")
        check("html total color",   yesIf(htmlTotals.contains("#3B6FD4")), "y")
        check("html total border",  yesIf(htmlTotals.contains("border-top:2px solid #7DA7F2")), "y")
        check("html tabular-nums",  yesIf(htmlTotals.contains("tabular-nums")), "y")
        check("html client cell",   yesIf(htmlTotals.contains(">Acme<")), "y")
        check("html totals no indent", yesIf(!htmlTotals.contains("padding-left:24px")), "y")

        let htmlByDay = dstore.recapHTML(monthKey: mk, byDay: true)
        check("html byday indent",  yesIf(htmlByDay.contains("padding-left:24px")), "y")
        check("html byday day cell", yesIf(htmlByDay.contains(">\(DateHelp.shortDayLabel(d5))<")), "y")

        let emailHTML = dstore.recapEmailHTML(monthKey: mk, byDay: false)
        check("email html greeting", yesIf(emailHTML.contains("here are my hours for \(DateHelp.monthName(fromKey: mk))")), "y")
        check("email html signature", yesIf(emailHTML.contains("Rahul Gonsalves")), "y")

        try? FileManager.default.removeItem(at: ddir)

        // HTML escaping of client names.
        let edir = FileManager.default.temporaryDirectory
            .appendingPathComponent("timekeep-selftest-\(UUID().uuidString)")
        let estore = TimeStore(directory: edir)
        _ = estore.addEntry(client: "A & <B>", hours: 1, note: "", date: d5)
        let escHTML = estore.recapHTML(monthKey: mk, byDay: false)
        check("html escapes", yesIf(escHTML.contains("A &amp; &lt;B&gt;") && !escHTML.contains("<B>")), "y")
        try? FileManager.default.removeItem(at: edir)

        // --- Client autocomplete (starts-with, sorted, exclude exact, ghost) ---
        let names = ["Acme Co", "Acme Industries", "acme services", "Beta LLC", "Zeta"]
        check("ac starts-with sorted",
              Autocomplete.matches(query: "ac", names: names).joined(separator: "|"),
              "Acme Co|Acme Industries|acme services")
        check("ac empty → none", yesIf(Autocomplete.matches(query: "  ", names: names).isEmpty), "y")
        check("ac not contains", yesIf(Autocomplete.matches(query: "eta", names: names).isEmpty), "y")
        check("ac excludes exact",
              yesIf(Autocomplete.matches(query: "Acme Co", names: names).isEmpty), "y")
        check("ac isExact ci", yesIf(Autocomplete.isExact(query: "acme co", names: names)), "y")
        check("ac not exact", yesIf(Autocomplete.isExact(query: "acme", names: names)), "n")
        check("ac ghost", Autocomplete.ghost(query: "Ac", suggestion: "Acme Co"), "me Co")
        check("ac ghost ci", Autocomplete.ghost(query: "ac", suggestion: "Acme Co"), "me Co")
        check("ac ghost none", Autocomplete.ghost(query: "Acme Co", suggestion: "Acme Co"), "")

        // Client name auto-capitalization (word-first, preserving the rest).
        let capDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("timekeep-selftest-\(UUID().uuidString)")
        let capStore = TimeStore(directory: capDir)
        _ = capStore.addEntry(client: "client input", hours: 1, note: "")
        _ = capStore.addEntry(client: "beta LLC", hours: 1, note: "")
        check("cap words", capStore.entries.first { $0.client.hasPrefix("Client") }?.client ?? "", "Client Input")
        check("cap preserves rest", capStore.entries.first { $0.client.hasPrefix("Beta") }?.client ?? "", "Beta LLC")
        try? FileManager.default.removeItem(at: capDir)

        print(failures == 0 ? "\nALL PASS" : "\n\(failures) FAILURE(S)")
        exit(failures == 0 ? 0 : 1)
    }
}
