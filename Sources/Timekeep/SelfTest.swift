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

        print(failures == 0 ? "\nALL PASS" : "\n\(failures) FAILURE(S)")
        exit(failures == 0 ? 0 : 1)
    }
}
