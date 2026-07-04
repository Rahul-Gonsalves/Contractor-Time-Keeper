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

    var body: some View {
        Card {
            SectionLabel(text: "Clients")
                .padding(.bottom, 12)

            if clientRows.isEmpty {
                Text("Clients appear here as you log time.")
                    .font(Theme.ui(13.5))
                    .foregroundColor(Theme.faint)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 4) {
                    ForEach(clientRows) { row in
                        ClientRowView(
                            name: row.id,
                            monthLabel: row.monthLabel,
                            totalLabel: row.totalLabel,
                            active: filterClient == row.id,
                            onSelect: { selectClient(row.id) }
                        )
                    }
                }
            }
        }
    }
}
