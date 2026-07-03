import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Reports the log form's available width so it can wrap on small windows.
private struct FormWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

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
    @State private var recapNotice: String? = nil
    @State private var noticeToken = 0
    @AppStorage(SettingsKeys.recapRecipient) private var recapRecipient = ""
    @AppStorage("recapByDay") private var recapByDay = false
    @State private var formWidth: CGFloat = 0

    // Client autocomplete
    @FocusState private var focus: LogField?
    @State private var acHighlighted = 0
    @State private var acDismissed = false

    private let controlHeight: CGFloat = 40
    private let maxContentWidth: CGFloat = 1160

    private var curMonth: String { DateHelp.monthKey(Date()) }

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width >= 900
            VStack(spacing: 0) {
                header
                ScrollView {
                    layout(wide: wide)
                        .frame(maxWidth: maxContentWidth, alignment: .top)
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
        .frame(maxWidth: maxContentWidth)      // cap content to the same column as the body
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)            // center it; margins grow with the window
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.hairline).frame(height: 1)   // border spans full width
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
        Autocomplete.matches(query: formClient, names: allClientNames)
    }
    private var clientTypedIsExact: Bool {
        Autocomplete.isExact(query: formClient, names: allClientNames)
    }
    private var suggestionsVisible: Bool {
        focus == .client && !acDismissed && !clientSuggestions.isEmpty
    }
    private var acClamped: Int { max(0, min(acHighlighted, clientSuggestions.count - 1)) }
    private var clientGhost: String {
        guard suggestionsVisible else { return "" }
        return Autocomplete.ghost(query: formClient, suggestion: clientSuggestions[acClamped])
    }

    /// The Client field: styled input + ghost text + focus + key handling; the
    /// dropdown itself is drawn as a form-level overlay anchored to this frame.
    private var clientField: some View {
        InsetField(placeholder: "Client", text: $formClient, height: controlHeight,
                   ghostSuffix: clientGhost,
                   focusBinding: $focus, focusCase: .client,
                   onSubmit: clientReturn)
            .frame(maxWidth: .infinity)
            .anchorPreference(key: ClientAnchorKey.self, value: .bounds) { $0 }
            .onChange(of: formClient) { _ in acHighlighted = 0; acDismissed = false }
            .onFieldKeys(
                enabled: suggestionsVisible,
                up: { acHighlighted = max(acClamped - 1, 0) },
                down: { acHighlighted = min(acClamped + 1, clientSuggestions.count - 1) },
                tab: { acceptSuggestion(0) },        // Tab accepts the first suggestion
                escape: { acDismissed = true }
            )
    }

    /// Return in the Client field: accept the highlighted suggestion (and move to
    /// Hours) when the list is up and the text isn't already an exact client; else
    /// submit the form normally.
    private func clientReturn() {
        if suggestionsVisible && !clientTypedIsExact {
            acceptSuggestion(acClamped)
        } else {
            submitAdd()
        }
    }

    private func acceptSuggestion(_ index: Int) {
        let list = clientSuggestions
        guard index >= 0, index < list.count else { return }
        formClient = list[index]
        acDismissed = true
        focus = .hours
    }

    private var logTimeCard: some View {
        Card {
            SectionLabel(text: "Log time")
                .padding(.bottom, 14)

            logForm
                .background(
                    GeometryReader { g in
                        Color.clear.preference(key: FormWidthKey.self, value: g.size.width)
                    }
                )
                .onPreferenceChange(FormWidthKey.self) { formWidth = $0 }
                .overlayPreferenceValue(ClientAnchorKey.self) { anchor in
                    GeometryReader { proxy in
                        if suggestionsVisible, let anchor {
                            let rect = proxy[anchor]
                            SuggestionsDropdown(
                                suggestions: Array(clientSuggestions.prefix(8)),
                                highlighted: acClamped,
                                onPick: acceptSuggestion
                            )
                            .frame(width: rect.width)
                            .offset(x: rect.minX, y: rect.maxY + 4)
                        }
                    }
                }
                .zIndex(10)

            if let hint = mergeHint {
                Text(hint)
                    .font(Theme.ui(12.5))
                    .foregroundColor(Theme.accent)
                    .padding(.top, 10)
            }
        }
    }

    /// Wide (>= 700pt) three-column grid; wraps to a stacked layout below that.
    @ViewBuilder
    private var logForm: some View {
        if formWidth > 0 && formWidth < 700 {
            VStack(spacing: 10) {
                clientField
                HStack(spacing: 10) {
                    DateFieldBox(date: $formDate, height: controlHeight, fillWidth: true)
                        .frame(minWidth: 90, maxWidth: .infinity)
                    InsetField(placeholder: "Hours", text: $formHours,
                               height: controlHeight,
                               focusBinding: $focus, focusCase: .hours, onSubmit: submitAdd)
                        .frame(minWidth: 90, maxWidth: .infinity)
                }
                InsetField(placeholder: "Note (optional)", text: $formNote,
                           fontSize: 14, height: controlHeight, onSubmit: submitAdd)
                    .frame(maxWidth: .infinity)
                AddButton(height: controlHeight, action: submitAdd)
                    .frame(maxWidth: .infinity)
            }
            .frame(maxWidth: .infinity)
        } else {
            Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 10) {
                GridRow {
                    clientField
                    DateFieldBox(date: $formDate, height: controlHeight, fillWidth: true)
                        .frame(width: 150)
                    InsetField(placeholder: "Hours", text: $formHours,
                               height: controlHeight,
                               focusBinding: $focus, focusCase: .hours, onSubmit: submitAdd)
                        .frame(width: 110)
                }
                GridRow {
                    InsetField(placeholder: "Note (optional)", text: $formNote,
                               fontSize: 14, height: controlHeight, onSubmit: submitAdd)
                        .frame(maxWidth: .infinity)
                        .gridCellColumns(2)
                    AddButton(height: controlHeight, action: submitAdd)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(maxWidth: .infinity)
        }
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

            HStack(spacing: 6) {
                RecapModeToggle(byDay: $recapByDay)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(store.recap(monthKey: recapMonth, byDay: recapByDay))
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
                    .contextMenu {
                        Button("Copy recap", action: copyRecap)
                        Button("Copy formatted (for email)", action: copyFormatted)
                    }
                GhostButton(title: "Export .xlsx", action: exportXLSX)
                GhostButton(title: "Draft email", disabled: !monthHasHours, action: draftEmail)
            }

            if let notice = recapNotice {
                Text(notice)
                    .font(Theme.ui(12.5))
                    .foregroundColor(Theme.muted)
                    .padding(.top, 10)
            }
        }
    }

    private var monthHasHours: Bool { store.monthTotal(recapMonth) > 0 }

    private func copyRecap() {
        let text = store.recap(monthKey: recapMonth, byDay: recapByDay)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        flashCopied()
    }

    /// Copy the formatted (HTML) recap plus a plain-text fallback: pasting into
    /// Outlook/Gmail keeps the table; pasting into a plain field falls back to text.
    private func copyFormatted() {
        let html = store.recapHTML(monthKey: recapMonth, byDay: recapByDay)
        let plain = store.recap(monthKey: recapMonth, byDay: recapByDay)
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(html, forType: .html)
        pb.setString(plain, forType: .string)
        flashCopied()
    }

    private func flashCopied() {
        copied = true
        copyToken += 1
        let token = copyToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            if copyToken == token { copied = false }
        }
    }

    private func exportXLSX() {
        let clients = store.aggregate(monthKey: recapMonth)
        let monthLabel = DateHelp.monthLabel(fromKey: recapMonth)
        let byDay = recapByDay
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "recap-\(recapMonth).xlsx"
        panel.allowedContentTypes = [UTType(filenameExtension: "xlsx") ?? .data]
        panel.canCreateDirectories = true
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            XLSXExport.write(to: url, monthLabel: monthLabel, clients: clients, byDay: byDay)
        }
    }

    /// Open a pre-filled recap draft. Prefers a rich-text compose window via
    /// NSSharingService (formatted HTML); falls back to a plain-text mailto: draft in
    /// Outlook / the default mail client. Timekeep never sends — the user reviews.
    private func draftEmail() {
        let subject = store.recapSubject(monthKey: recapMonth)
        let to = recapRecipient.trimmingCharacters(in: .whitespacesAndNewlines)

        // Preferred: rich-text compose via NSSharingService.
        let html = store.recapEmailHTML(monthKey: recapMonth, byDay: recapByDay)
        if let attr = attributedString(fromHTML: html),
           let service = NSSharingService(named: .composeEmail),
           service.canPerform(withItems: [attr]) {
            service.subject = subject
            if !to.isEmpty { service.recipients = [to] }
            service.perform(withItems: [attr])
            return
        }

        // Fallback: plain-text mailto:.
        let body = store.recapEmailBody(monthKey: recapMonth, byDay: recapByDay)
        guard let url = MailDraft.mailtoURL(subject: subject, body: body, to: to) else { return }
        let ws = NSWorkspace.shared
        if let outlook = ws.urlForApplication(withBundleIdentifier: "com.microsoft.Outlook") {
            let config = NSWorkspace.OpenConfiguration()
            ws.open([url], withApplicationAt: outlook, configuration: config) { _, error in
                if error != nil {
                    DispatchQueue.main.async { openDefaultOrCopy(url, body: body) }
                }
            }
        } else {
            openDefaultOrCopy(url, body: body)
        }
    }

    private func attributedString(fromHTML html: String) -> NSAttributedString? {
        guard let data = html.data(using: .utf8) else { return nil }
        return try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil)
    }

    private func openDefaultOrCopy(_ url: URL, body: String) {
        if !NSWorkspace.shared.open(url) {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(body, forType: .string)
            setRecapNotice("No mail app found — recap copied instead.")
        }
    }

    private func setRecapNotice(_ notice: String) {
        recapNotice = notice
        noticeToken += 1
        let token = noticeToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if noticeToken == token { recapNotice = nil }
        }
    }
}
