import SwiftUI

/// Entries timeline for one month. Equatable so it isn't rebuilt when unrelated
/// parent state (e.g. the log form text) changes — only when the month, the client
/// filter, or the entries themselves change. Edit state is local to this view.
struct TimelineCard: View, Equatable {
    @ObservedObject var store: TimeStore
    let monthKey: String
    let filterClient: String?
    let clearFilter: () -> Void

    @State private var editingID: UUID? = nil
    @State private var editHours = ""
    @State private var editNote = ""
    @State private var editDate = Date()

    static func == (l: TimelineCard, r: TimelineCard) -> Bool {
        l.monthKey == r.monthKey && l.filterClient == r.filterClient
    }

    private struct DayGroup: Identifiable {
        let id: Date
        let label: String
        let totalLabel: String
        let entries: [TimeEntry]
    }

    private var visibleEntries: [TimeEntry] {
        store.entries.filter {
            DateHelp.monthKey($0.date) == monthKey && (filterClient == nil || $0.client == filterClient)
        }
    }

    private var dayGroups: [DayGroup] {
        let grouped = Dictionary(grouping: visibleEntries) { DateHelp.cal.startOfDay(for: $0.date) }
        return grouped.keys.sorted(by: >).map { day in
            let list = grouped[day] ?? []
            return DayGroup(id: day,
                            label: DateHelp.dayLabel(day),
                            totalLabel: formatHours(list.reduce(0) { $0 + $1.hours }),
                            entries: list)
        }
    }

    var body: some View {
        Card {
            HStack(spacing: 10) {
                SectionLabel(text: "Entries")
                Spacer(minLength: 10)
                if let f = filterClient {
                    Button(action: clearFilter) {
                        Text("\(f) · clear")
                            .font(Theme.ui(12.5, .semibold))
                            .foregroundColor(Theme.accent)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 12)
                            .background(Theme.accentTint12)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.pillRadius))
                            .overlay(RoundedRectangle(cornerRadius: Theme.pillRadius)
                                .stroke(Theme.accentBorder30, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 6)

            if visibleEntries.isEmpty {
                Text("No entries in \(DateHelp.monthLabel(fromKey: monthKey)).")
                    .font(Theme.ui(14))
                    .foregroundColor(Theme.faint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .padding(.horizontal, 8)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(dayGroups) { day in dayGroupView(day) }
                }
            }
        }
    }

    @ViewBuilder
    private func dayGroupView(_ day: DayGroup) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(day.label)
                    .font(Theme.ui(13, .semibold))
                    .foregroundColor(Theme.textSecondary)
                Spacer(minLength: 10)
                Text(day.totalLabel)
                    .font(Theme.mono(12.5))
                    .foregroundColor(Theme.faint)
            }
            .padding(.bottom, 8)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }

            ForEach(day.entries) { entry in
                EntryRow(
                    entry: entry,
                    isEditing: editingID == entry.id,
                    editHours: $editHours,
                    editNote: $editNote,
                    editDate: $editDate,
                    onStartEdit: {
                        editingID = entry.id
                        editHours = trimmedHoursString(entry.hours)
                        editNote = entry.note
                        editDate = entry.date
                    },
                    onSave: {
                        if let h = Double(editHours.trimmingCharacters(in: .whitespaces)),
                           store.updateEntry(id: entry.id, hours: h, note: editNote, date: editDate) {
                            editingID = nil
                        }
                    },
                    onCancel: { editingID = nil },
                    onDelete: {
                        store.deleteEntry(id: entry.id)
                        if editingID == entry.id { editingID = nil }
                    }
                )
            }
        }
        .padding(.top, 14)
    }

    private func trimmedHoursString(_ h: Double) -> String {
        if h == h.rounded() { return String(Int(h)) }
        var s = String(format: "%.2f", h)
        while s.hasSuffix("0") { s.removeLast() }
        if s.hasSuffix(".") { s.removeLast() }
        return s
    }
}
