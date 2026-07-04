import SwiftUI

/// Clients list. Equatable so it isn't rebuilt on unrelated parent state changes —
/// only when the selected month, the filter, or the entries change.
struct ClientsPanel: View, Equatable {
    @ObservedObject var store: TimeStore
    let monthKey: String
    let filterClient: String?
    let selectClient: (String) -> Void

    static func == (l: ClientsPanel, r: ClientsPanel) -> Bool {
        l.monthKey == r.monthKey && l.filterClient == r.filterClient
    }

    private struct ClientRow: Identifiable {
        let id: String
        let monthLabel: String
        let totalLabel: String
    }

    private var clientRows: [ClientRow] {
        struct Agg { var month = 0.0; var total = 0.0 }
        var agg: [String: Agg] = [:]
        var order: [String] = []
        for e in store.entries {
            if agg[e.client] == nil { order.append(e.client) }
            var a = agg[e.client] ?? Agg()
            a.total += e.hours
            if DateHelp.monthKey(e.date) == monthKey { a.month += e.hours }
            agg[e.client] = a
        }
        return order
            .sorted {
                let a = agg[$0]!, b = agg[$1]!
                if a.month != b.month { return a.month > b.month }
                if a.total != b.total { return a.total > b.total }
                return $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
            .map { name in
                ClientRow(id: name,
                          monthLabel: formatHours(agg[name]!.month),
                          totalLabel: formatHours(agg[name]!.total) + " all")
            }
    }

    @State private var showInternal = false   // tab selection (local; not part of ==)

    var body: some View {
        Card {
            HStack(spacing: 10) {
                SectionLabel(text: "Clients")
                Spacer(minLength: 10)
                PillToggle(left: "Clients", right: "Internal", isRight: $showInternal)
            }
            .padding(.bottom, 12)

            let rows = clientRows.filter { store.isInternal($0.id) == showInternal }

            if rows.isEmpty {
                Text(showInternal ? "No internal systems yet."
                                  : "Clients appear here as you log time.")
                    .font(Theme.ui(13.5))
                    .foregroundColor(Theme.faint)
                    .padding(.vertical, 6)
            } else {
                rowList(rows)
            }
        }
    }

    private func rowList(_ rows: [ClientRow]) -> some View {
        VStack(spacing: 4) {
            ForEach(rows) { row in
                ClientRowView(
                    name: row.id,
                    monthLabel: row.monthLabel,
                    totalLabel: row.totalLabel,
                    active: filterClient == row.id,
                    onSelect: { selectClient(row.id) }
                )
                .contextMenu {
                    if store.isInternal(row.id) {
                        Button("Mark as client") { store.setInternal(row.id, false) }
                    } else {
                        Button("Mark as internal") { store.setInternal(row.id, true) }
                    }
                }
            }
        }
    }
}
