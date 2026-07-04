import SwiftUI
import AppKit

/// Reports the log form's available width so it can wrap on small windows.
private struct FormWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Window width, read without wrapping the whole layout in a GeometryReader (which
/// would force a full relayout every resize frame).
private struct WindowWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 1160
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

struct ContentView: View {
    @StateObject private var store = TimeStore()

    // Log form state (kept local to the parent; the heavy cards below are separate,
    // Equatable views so typing here doesn't rebuild them).
    @State private var formClient = ""
    @State private var formHours = ""
    @State private var formNote = ""
    @State private var formDate = Date()
    @State private var formInternal = false

    @State private var filterClient: String? = nil
    @State private var recapMonth: String = DateHelp.monthKey(Date())

    @State private var mergeHint: String? = nil
    @State private var hintToken = 0
    @State private var formWidth: CGFloat = 0
    @State private var windowWidth: CGFloat = 1160

    @AppStorage("recapByDay") private var recapByDay = false
    @AppStorage(SettingsKeys.hourlyRate) private var hourlyRate = 20.0

    // Client autocomplete
    @FocusState private var focus: LogField?
    @State private var acHighlighted = 0
    @State private var acDismissed = false

    private let controlHeight: CGFloat = 40
    private let maxContentWidth: CGFloat = 1160

    private var curMonth: String { DateHelp.monthKey(Date()) }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                layout(wide: windowWidth >= 900)
                    .frame(maxWidth: maxContentWidth, alignment: .top)
                    .padding(.horizontal, 32)
                    .padding(.top, 24)
                    .padding(.bottom, 48)
                    .frame(maxWidth: .infinity)
            }
            footer
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Theme.page)
        .background(
            GeometryReader { g in Color.clear.preference(key: WindowWidthKey.self, value: g.size.width) }
        )
        .onPreferenceChange(WindowWidthKey.self) { windowWidth = $0 }
    }

    // MARK: - Footer

    private var footer: some View {
        Button(action: openSettings) {
            HStack(spacing: 6) {
                Text("⌘ ,")
                    .font(Theme.mono(11))
                    .foregroundColor(Theme.faint)
                    .padding(.vertical, 1)
                    .padding(.horizontal, 5)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Theme.inputBorder, lineWidth: 1))
                Text("Settings")
                    .font(Theme.ui(11))
                    .foregroundColor(Theme.faint)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 32)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
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
                if hourlyRate > 0 {
                    Text(formatMoney(store.monthTotal(curMonth) * hourlyRate))
                        .font(Theme.mono(15, .semibold))
                        .foregroundColor(Theme.success)
                        .padding(.leading, 4)
                }
            }
        }
        .padding(.top, 22)
        .padding(.bottom, 18)
        .frame(maxWidth: maxContentWidth)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }

    // MARK: - Layout (Clients right)

    @ViewBuilder
    private func layout(wide: Bool) -> some View {
        if wide {
            HStack(alignment: .top, spacing: 20) {
                mainColumn.frame(maxWidth: .infinity, alignment: .top)
                sideColumn.frame(width: 380, alignment: .top)
            }
        } else {
            VStack(spacing: 20) { mainColumn; sideColumn }
        }
    }

    private var mainColumn: some View {
        VStack(spacing: 20) {
            logTimeCard
            TimelineCard(store: store, monthKey: recapMonth,
                         filterClient: filterClient, clearFilter: { filterClient = nil })
                .equatable()
        }
        // Host the autocomplete dropdown above the cards (outside their clipping).
        .overlayPreferenceValue(ClientAnchorKey.self) { anchor in
            GeometryReader { proxy in
                if suggestionsVisible, let anchor {
                    let rect = proxy[anchor]
                    SuggestionsDropdown(suggestions: clientSuggestions,
                                        highlighted: acClamped,
                                        onPick: acceptSuggestion)
                        .frame(width: rect.width)
                        .offset(x: rect.minX, y: rect.maxY + 4)
                }
            }
        }
    }

    private var sideColumn: some View {
        VStack(spacing: 20) {
            ClientsPanel(store: store, monthKey: recapMonth, filterClient: filterClient,
                         selectClient: { name in filterClient = (filterClient == name) ? nil : name })
                .equatable()
            RecapCardView(store: store, recapMonth: $recapMonth, recapByDay: $recapByDay)
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

    private var clientSuggestions: [String] { Autocomplete.matches(query: formClient, names: allClientNames) }
    private var clientTypedIsExact: Bool { Autocomplete.isExact(query: formClient, names: allClientNames) }
    private var suggestionsVisible: Bool { focus == .client && !acDismissed && !clientSuggestions.isEmpty }
    private var acClamped: Int { max(0, min(acHighlighted, clientSuggestions.count - 1)) }
    private var clientGhost: String {
        guard suggestionsVisible else { return "" }
        return Autocomplete.ghost(query: formClient, suggestion: clientSuggestions[acClamped])
    }

    private var clientField: some View {
        InsetField(placeholder: "Client", text: $formClient, height: controlHeight,
                   ghostSuffix: clientGhost,
                   focusBinding: $focus, focusCase: .client,
                   onSubmit: clientReturn)
            .frame(maxWidth: .infinity)
            .anchorPreference(key: ClientAnchorKey.self, value: .bounds) { $0 }
            .onChange(of: formClient) { _ in
                acHighlighted = 0; acDismissed = false
                // When the text matches an existing client, reflect its stored kind.
                if let existing = allClientNames.first(where: {
                    $0.compare(formClient.trimmingCharacters(in: .whitespaces),
                               options: .caseInsensitive) == .orderedSame
                }) {
                    formInternal = store.isInternal(existing)
                }
            }
            .onFieldKeys(
                enabled: suggestionsVisible,
                up: { acHighlighted = max(acClamped - 1, 0) },
                down: { acHighlighted = min(acClamped + 1, clientSuggestions.count - 1) },
                tab: { acceptSuggestion(0) },
                escape: { acDismissed = true }
            )
    }

    private func clientReturn() {
        if suggestionsVisible && !clientTypedIsExact { acceptSuggestion(acClamped) } else { submitAdd() }
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
                    GeometryReader { g in Color.clear.preference(key: FormWidthKey.self, value: g.size.width) }
                )
                .onPreferenceChange(FormWidthKey.self) { formWidth = $0 }

            HStack(spacing: 6) {
                PillToggle(left: "Client", right: "Internal", isRight: $formInternal)
                Spacer(minLength: 0)
            }
            .padding(.top, 10)

            if let hint = mergeHint {
                Text(hint)
                    .font(Theme.ui(12.5))
                    .foregroundColor(Theme.accent)
                    .padding(.top, 10)
            }
        }
    }

    @ViewBuilder
    private var logForm: some View {
        if formWidth > 0 && formWidth < 700 {
            VStack(spacing: 10) {
                clientField
                HStack(spacing: 10) {
                    DateFieldBox(date: $formDate, height: controlHeight, fillWidth: true)
                        .frame(minWidth: 90, maxWidth: .infinity)
                    InsetField(placeholder: "Hours", text: $formHours, height: controlHeight,
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
                    InsetField(placeholder: "Hours", text: $formHours, height: controlHeight,
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
        let hint = store.addEntry(client: formClient, hours: hours, note: formNote,
                                  date: formDate, isInternal: formInternal)
        guard !formClient.trimmingCharacters(in: .whitespaces).isEmpty, hours > 0 else { return }
        formClient = ""; formHours = ""; formNote = ""; formDate = Date(); formInternal = false
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
}
