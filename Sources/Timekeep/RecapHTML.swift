import Foundation

/// Email-safe HTML rendering of the recap: <table>-based, all styles inline, no
/// external CSS/fonts/images. Designed for white email backgrounds (not the app's
/// dark theme). No notes, ever.
extension TimeStore {
    private static let sans = "font-family:Helvetica,Arial,sans-serif;"

    private func esc(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private func htmlRow(left: String, right: String,
                         leftExtra: String, rightExtra: String, border: Bool) -> String {
        let cell = "\(Self.sans)font-size:14px;padding:10px;"
        let b = border ? "border-bottom:1px solid #E4E9F0;" : ""
        return "<tr>"
            + "<td style=\"text-align:left;\(cell)\(b)\(leftExtra)\">\(left)</td>"
            + "<td style=\"text-align:right;\(cell)\(b)font-variant-numeric:tabular-nums;\(rightExtra)\">\(right)</td>"
            + "</tr>"
    }

    /// The recap heading + table (no greeting/signature). Used by "Copy formatted".
    func recapHTML(monthKey: String, byDay: Bool) -> String {
        let label = esc(DateHelp.monthLabel(fromKey: monthKey))
        let heading = "<div style=\"\(Self.sans)font-size:18px;font-weight:600;color:#1D2632;margin:0 0 12px;\">"
            + "Time recap — \(label)</div>"

        let clients = aggregate(monthKey: monthKey)
        if clients.isEmpty {
            return "<div style=\"\(Self.sans)\">\(heading)"
                + "<div style=\"\(Self.sans)font-size:14px;color:#5C6B7E;\">No hours logged.</div></div>"
        }

        let th = "background:#F1F4F8;color:#5C6B7E;\(Self.sans)font-size:12px;"
            + "letter-spacing:0.08em;text-transform:uppercase;padding:8px 10px;"
        var rows = "<tr>"
            + "<th style=\"text-align:left;\(th)\">Client</th>"
            + "<th style=\"text-align:right;\(th)\">Hours</th>"
            + "</tr>"

        var total: Double = 0
        for (i, c) in clients.enumerated() {
            total += c.total
            if byDay {
                // Bold subtotal row; blank-line-equivalent gap above all but the first.
                let gap = i == 0 ? "" : "padding-top:16px;"
                rows += htmlRow(left: esc(c.name), right: formatHours(c.total),
                                leftExtra: "font-weight:700;color:#1D2632;\(gap)",
                                rightExtra: "font-weight:700;color:#1D2632;\(gap)",
                                border: false)
                for d in c.days {
                    rows += htmlRow(left: esc(DateHelp.shortDayLabel(d.date)),
                                    right: formatHours(d.hours),
                                    leftExtra: "color:#5C6B7E;padding-left:24px;",
                                    rightExtra: "color:#5C6B7E;",
                                    border: true)
                }
            } else {
                rows += htmlRow(left: esc(c.name), right: formatHours(c.total),
                                leftExtra: "color:#1D2632;",
                                rightExtra: "color:#1D2632;",
                                border: true)
            }
        }

        let totalCell = "\(Self.sans)font-size:14px;font-weight:700;padding:10px;border-top:2px solid #7DA7F2;"
        rows += "<tr>"
            + "<td style=\"text-align:left;\(totalCell)color:#1D2632;\">Total</td>"
            + "<td style=\"text-align:right;\(totalCell)color:#3B6FD4;font-variant-numeric:tabular-nums;\">"
            + "\(formatHours(total))</td>"
            + "</tr>"

        let table = "<table cellspacing=\"0\" cellpadding=\"0\" role=\"presentation\" "
            + "style=\"width:100%;max-width:560px;border-collapse:collapse;\">\(rows)</table>"
        return "<div style=\"\(Self.sans)\">\(heading)\(table)</div>"
    }

    /// Full HTML email body: greeting + recap table + signature. Used by "Draft email".
    func recapEmailHTML(monthKey: String, byDay: Bool) -> String {
        let month = esc(DateHelp.monthName(fromKey: monthKey))
        let p = "\(Self.sans)font-size:14px;color:#1D2632;line-height:1.5;"
        let greeting = "<p style=\"\(p)margin:0 0 12px;\">Hi,<br>here are my hours for \(month)</p>"
        let signature = "<p style=\"\(p)margin:16px 0 0;\">Thanks,<br>Rahul Gonsalves</p>"
        return "<div style=\"\(Self.sans)\">\(greeting)\(recapHTML(monthKey: monthKey, byDay: byDay))\(signature)</div>"
    }
}
