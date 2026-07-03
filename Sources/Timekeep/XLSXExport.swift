import Foundation
import xlsxwriter

/// Writes a formatted .xlsx recap that mirrors the HTML recap email. Hours are real
/// numbers (so they sum/format in Excel); the Total is a live SUM formula. No notes.
enum XLSXExport {
    static func write(to url: URL,
                      monthLabel: String,
                      clients: [TimeStore.RecapClient],
                      byDay: Bool) {
        let wb = Workbook(name: url.path)

        let ws = wb.addWorksheet(name: sanitizeSheetName(monthLabel))

        // Palette — matches the HTML recap email.
        let slate     = Color(hex: 0x1D2632)
        let muted     = Color(hex: 0x5C6B7E)
        let headerBg  = Color(hex: 0xF1F4F8)
        let rowBorder = Color(hex: 0xE4E9F0)
        let accent    = Color(hex: 0x7DA7F2)
        let totalBlue = Color(hex: 0x3B6FD4)
        let numFmt    = "0.##"   // drops trailing zeros: 2, 2.5, 0.75

        // Title, merged across both columns.
        let titleFmt = wb.addFormat()
        titleFmt.bold().font(size: 16).font(color: slate).align(vertical: .center)
        ws.merge(range: [0, 0, 0, 1], string: "Time recap — \(monthLabel)", format: titleFmt)

        ws.column("A:A", width: 32)
        ws.column("B:B", width: 10)

        guard !clients.isEmpty else {
            let noteFmt = wb.addFormat()
            noteFmt.font(size: 12).font(color: muted)
            ws.write(.string("No hours logged."), [1, 0], format: noteFmt)
            wb.close()
            return
        }

        // Header row.
        let headerLeft = wb.addFormat()
        headerLeft.bold().font(size: 10).font(color: muted).background(color: headerBg)
            .align(horizontal: .left)
        let headerRight = wb.addFormat()
        headerRight.bold().font(size: 10).font(color: muted).background(color: headerBg)
            .align(horizontal: .right)
        ws.write(.string("CLIENT"), [1, 0], format: headerLeft)
        ws.write(.string("HOURS"), [1, 1], format: headerRight)

        // Row formats.
        let clientName = wb.addFormat()
        clientName.font(size: 12).font(color: slate).align(horizontal: .left)
            .bottom(style: .thin).border(color: rowBorder)
        let clientHours = wb.addFormat()
        clientHours.font(size: 12).font(color: slate).align(horizontal: .right)
            .set(num_format: numFmt).bottom(style: .thin).border(color: rowBorder)

        let subtotalName = wb.addFormat()
        subtotalName.bold().font(size: 12).font(color: slate).align(horizontal: .left)
        let subtotalHours = wb.addFormat()
        subtotalHours.bold().font(size: 12).font(color: slate).align(horizontal: .right)
            .set(num_format: numFmt)

        let dayName = wb.addFormat()
        dayName.font(size: 12).font(color: muted).align(horizontal: .left)
            .bottom(style: .thin).border(color: rowBorder)
        let dayHours = wb.addFormat()
        dayHours.font(size: 12).font(color: muted).align(horizontal: .right)
            .set(num_format: numFmt).bottom(style: .thin).border(color: rowBorder)

        var r = 2
        var sumRefs: [String] = []   // A1 refs of the cells the Total should sum
        for c in clients {
            if byDay {
                // Bold subtotal row (its month total), then indented dated rows.
                ws.write(.string(c.name), [r, 0], format: subtotalName)
                ws.write(.number(round2(c.total)), [r, 1], format: subtotalHours)
                sumRefs.append("B\(r + 1)")
                r += 1
                for d in c.days {
                    ws.write(.string("    " + DateHelp.shortDayLabel(d.date)), [r, 0], format: dayName)
                    ws.write(.number(round2(d.hours)), [r, 1], format: dayHours)
                    r += 1
                }
            } else {
                ws.write(.string(c.name), [r, 0], format: clientName)
                ws.write(.number(round2(c.total)), [r, 1], format: clientHours)
                sumRefs.append("B\(r + 1)")
                r += 1
            }
        }

        // Total row — real SUM over the summed cells only (subtotals in By-day mode).
        let totalName = wb.addFormat()
        totalName.bold().font(size: 12).font(color: slate).align(horizontal: .left)
            .top(style: .medium).border(color: accent)
        let totalHours = wb.addFormat()
        totalHours.bold().font(size: 12).font(color: totalBlue).align(horizontal: .right)
            .set(num_format: numFmt).top(style: .medium).border(color: accent)
        ws.write(.string("Total"), [r, 0], format: totalName)
        ws.write(.formula("=SUM(" + sumRefs.joined(separator: ",") + ")"), [r, 1], format: totalHours)

        wb.close()
    }

    private static func round2(_ v: Double) -> Double { (v * 100).rounded() / 100 }

    /// Excel forbids []:*?/\ in sheet names and caps them at 31 chars.
    private static func sanitizeSheetName(_ s: String) -> String {
        var out = s
        for ch in ["[", "]", ":", "*", "?", "/", "\\"] {
            out = out.replacingOccurrences(of: ch, with: " ")
        }
        return String(out.prefix(31))
    }
}
