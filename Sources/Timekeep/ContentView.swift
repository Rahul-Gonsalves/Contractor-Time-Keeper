import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var store = TimeStore()

    // Form state
    @State private var formClient = ""
    @State private var formHours = ""
    @State private var formNote = ""
    @State private var formDate = Date()

    // Filter / recap / edit
    @State private var filterClient: String? = nil
    @State private var recapMonth: String = DateHelp.monthKey(Date())
    @State private var editingID: UUID? = nil
    @State private var editHours = ""
    @State private var editNote = ""
    @State private var editDate = Date()

    // Transient UI
    @State private var mergeHint: String? = nil
    @State private var hintToken = 0
    @State private var copied = false
    @State private var copyToken = 0

    private var curMonth: String { DateHelp.monthKey(Date()) }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= 900
            VStack(spacing: 0) {
                header
                ScrollView {
                    layout(wide: wide)
                        .frame(maxWidth: 1160, alignment: .top)
                        .padding(.horizontal, 32)
                        .padding(.top, 24)
                        .padding(.bottom, 48)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.page)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                Text("Timekeep")
                    .font(Theme.ui(20, .bold))
                    .tracking(-0.2)
                    .foregroundColor(Theme.textPrimary)
                Text(DateHelp.todayLabel())
                    .font(Theme.ui(13))
                    .foregroundColor(Theme.muted)
            }
            Spacer(minLength: 16)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("This month")
                    .font(Theme.ui(13))
                    .foregroundColor(Theme.muted)
                Text(formatHours(store.monthTotal(curMonth)))
                    .font(Theme.mono(15, .semibold))
                    .foregroundColor(Theme.accent)
            }
        }
        .padding(.top, 22)
        .padding(.bottom, 18)
        .padding(.horizontal, 32)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.hairline).frame(height: 1)
        }
    }

    // MARK: - Layout (Clients right)

    @ViewBuilder
    private func layout(wide: Bool) -> some View {
        if wide {
            HStack(alignment: .top, spacing: 20) {
                mainColumn
                    .frame(maxWidth: .infinity, alignment: .top)
                sideColumn
                    .frame(width: 380, alignment: .top)
            }
        } else {
            VStack(spacing: 20) {
                mainColumn
                sideColumn
            }
        }
    }

    private var mainColumn: some View {
        VStack(spacing: 20) {
            logTimeCard
            timelineCard
        }
    }

    private var sideColumn: some View {
        VStack(spacing: 20) {
            clientsCard
            recapCard
        }
    }

    // MARK: - Card 1: Log time

    private var allClientNames: [String] {
        var seen = Set<String>()
        var names: [String] = []
        for e in store.entries where !seen.contains(e.client) {
            seen.insert(e.client)
            names.append(e.client)
        }
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var clientSuggestions: [String] {
        let q = formClient.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return allClientNames.filter {
            $0.localizedCaseInsensitiveContains(q) &&
            $0.compare(q, options: .caseInsensitive) != .orderedSame
        }
    }

    private var logTimeCard: some View {
        Card {
            SectionLabel(text: "Log time")
                .padding(.bottom, 14)

            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    InsetField(placeholder: "Client", text: $formClient, onSubmit: submitAdd)
                    InsetField(placeholder: "Hours", text: $formHours, onSubmit: submitAdd)
                        .frame(width: 110)
                }
                GridRow {
                    InsetField(placeholder: "Note (optional)", text: $formNote,
                               fontSize: 14, onSubmit: submitAdd)
                    addButton
                }
            }

            HStack(spacing: 8) {
                Text("Date")
                    .font(Theme.ui(12.5))
                    .foregroundColor(Theme.muted)
                InsetDatePicker(date: $formDate)
                Spacer(minLength: 0)
            }
            .padding(.top, 10)

            if !clientSuggestions.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(clientSuggestions.prefix(6), id: \.self) { name in
                        Button {
                            formClient = name
                        } label: {
                            Text(name)
                                .font(Theme.ui(14))
                                .foregroundColor(Theme.textSecondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                        }
                        .buttonStyle(.plain)
                        .background(Theme.inset)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                    }
                }
                .padding(.top, 8)
            }

            if let hint = mergeHint {
                Text(hint)
                    .font(Theme.ui(12.5))
                    .foregroundColor(Theme.accent)
                    .padding(.top, 10)
            }
        }
    }

    private var addButton: some View {
        AddButton(action: submitAdd)
    }

    private func submitAdd() {
        guard let hours = Double(formHours.trimmingCharacters(in: .whitespaces)) else { return }
        let hint = store.addEntry(client: formClient, hours: hours, note: formNote, date: formDate)
        guard !formClient.trimmingCharacters(in: .whitespaces).isEmpty, hours > 0 else { return }
        formClient = ""; formHours = ""; formNote = ""; formDate = Date()
        setMergeHint(hint)
    }

    private func setMergeHint(_ hint: String?) {
        mergeHint = hint
        guard hint != nil else { return }
        hintToken += 1
        let token = hintToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if hintToken == token { mergeHint = nil }
        }
    }

    // MARK: - Card 2: Entries (timeline)

    private var visibleEntries: [TimeEntry] {
        guard let f = filterClient else { return store.entries }
        return store.entries.filter { $0.client == f }
    }

    private struct DayGroup: Identifiable {
        let id: Date
        let label: String
        let totalLabel: String
        let entries: [TimeEntry]
    }

    private var dayGroups: [DayGroup] {
        let grouped = Dictionary(grouping: visibleEntries) {
            DateHelp.cal.startOfDay(for: $0.date)
        }
        return grouped.keys.sorted(by: >).map { day in
            let list = grouped[day] ?? []
            let total = list.reduce(0) { $0 + $1.hours }
            return DayGroup(id: day,
                            label: DateHelp.dayLabel(day),
                            totalLabel: formatHours(total),
                            entries: list)
        }
    }

    private var timelineCard: some View {
        Card {
            HStack(spacing: 10) {
                SectionLabel(text: "Entries")
                Spacer(minLength: 10)
                if let f = filterClient {
                    Button {
                        filterClient = nil
                    } label: {
                        Text("\(f) · clear")
                            .font(Theme.ui(12.5, .semibold))
                            .foregroundColor(Theme.accent)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 12)
                            .background(Theme.accentTint12)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.pillRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: Theme.pillRadius)
                                    .stroke(Theme.accentBorder30, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 6)

            if visibleEntries.isEmpty {
                Text("No entries yet. Log your first hours above — the date is filled in automatically.")
                    .font(Theme.ui(14))
                    .foregroundColor(Theme.faint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                    .padding(.horizontal, 8)
            } else {
                ForEach(dayGroups) { day in
                    dayGroupView(day)
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
            .overlay(alignment: .bottom) {
                Rectangle().fill(Theme.hairline).frame(height: 1)
            }

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

    // MARK: - Card 3: Clients

    private struct ClientRow: Identifiable {
        let id = UUID()
        let name: String
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
            if DateHelp.monthKey(e.date) == curMonth { a.month += e.hours }
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
                ClientRow(name: name,
                          monthLabel: formatHours(agg[name]!.month),
                          totalLabel: formatHours(agg[name]!.total) + " all")
            }
    }

    private var clientsCard: some View {
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
                            name: row.name,
                            monthLabel: row.monthLabel,
                            totalLabel: row.totalLabel,
                            active: filterClient == row.name,
                            onSelect: {
                                filterClient = (filterClient == row.name) ? nil : row.name
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Card 4: Monthly recap

    private var recapCard: some View {
        Card {
            HStack(spacing: 10) {
                SectionLabel(text: "Monthly recap")
                Spacer(minLength: 10)
                MonthPicker(selection: $recapMonth, options: store.monthOptions())
            }
            .padding(.bottom, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(store.recapText(monthKey: recapMonth))
                    .font(Theme.mono(12.5))
                    .foregroundColor(Color(hex: "CFD9E6"))
                    .lineSpacing(12.5 * 0.7) // 1.7 line-height
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Theme.inset)
            .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.controlRadius)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
            .padding(.bottom, 12)

            HStack(spacing: 8) {
                CopyButton(copied: copied, action: copyRecap)
                ExportButton(action: exportTxt)
            }
        }
    }

    private func copyRecap() {
        let text = store.recapText(monthKey: recapMonth)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        copied = true
        copyToken += 1
        let token = copyToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copyToken == token { copied = false }
        }
    }

    private func exportTxt() {
        let text = store.recapText(monthKey: recapMonth)
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "recap-\(recapMonth).txt"
        panel.allowedContentTypes = [.plainText]
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? text.data(using: .utf8)?.write(to: url, options: .atomic)
        }
    }
}
