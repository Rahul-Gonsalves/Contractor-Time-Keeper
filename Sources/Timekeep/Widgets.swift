import SwiftUI

/// Accent "Add" button: lightens on hover.
struct AddButton: View {
    var height: CGFloat? = nil
    let action: () -> Void
    @State private var hovering = false
    var body: some View {
        Button(action: action) {
            Text("Add")
                .font(Theme.ui(15, .bold))
                .foregroundColor(Theme.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .frame(height: height)   // nil → natural height
                .background(hovering ? Theme.accentHover : Theme.accent)
                .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// A single timeline entry — normal row or inline edit state.
struct EntryRow: View {
    let entry: TimeEntry
    let isEditing: Bool
    @Binding var editHours: String
    @Binding var editNote: String
    @Binding var editDate: Date
    let onStartEdit: () -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    let onDelete: () -> Void

    @State private var hovering = false

    var body: some View {
        Group {
            if isEditing {
                editRow
            } else {
                normalRow
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.rowSeparator).frame(height: 1)
        }
    }

    private var normalRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(entry.client)
                .font(Theme.ui(14.5, .semibold))
                .foregroundColor(Theme.textPrimary)
                .fixedSize(horizontal: true, vertical: false)
            if !entry.note.isEmpty {
                Text(entry.note)
                    .font(Theme.ui(13))
                    .foregroundColor(Theme.muted)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 12)
            Text(formatHours(entry.hours))
                .font(Theme.mono(14))
                .foregroundColor(Color(hex: "CFD9E6"))
                .fixedSize()
            HStack(spacing: 4) {
                HoverTextButton(title: "Edit",
                                hoverColor: Theme.accent,
                                hoverBg: Theme.accentTint10,
                                action: onStartEdit)
                HoverTextButton(title: "Delete",
                                hoverColor: Theme.danger,
                                hoverBg: Theme.dangerTint10,
                                action: onDelete)
            }
        }
        .padding(.vertical, 11)
        .background(hovering ? Color.white.opacity(0.015) : Color.clear)
        .onHover { hovering = $0 }
    }

    private var editRow: some View {
        HStack(spacing: 8) {
            InsetField(placeholder: "", text: $editHours,
                       fontSize: 14, radius: Theme.editRadius, vPad: 8, hPad: 10,
                       onSubmit: onSave)
                .frame(width: 90)
            DateFieldBox(date: $editDate, fontSize: 14, radius: Theme.editRadius, vPad: 8, hPad: 10)
            InsetField(placeholder: "Note (optional)", text: $editNote,
                       fontSize: 14, radius: Theme.editRadius, vPad: 8, hPad: 10,
                       onSubmit: onSave)
            Button(action: onSave) {
                Text("Save")
                    .font(Theme.ui(13, .bold))
                    .foregroundColor(Theme.onAccent)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 14)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.editRadius))
            }
            .buttonStyle(.plain)
            Button(action: onCancel) {
                Text("Cancel")
                    .font(Theme.ui(13))
                    .foregroundColor(Theme.muted)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 12)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.editRadius)
                            .stroke(Theme.inputBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.vertical, 10)
    }
}

/// A client row in the Clients panel; tints when selected (filter active) or hovered.
struct ClientRowView: View {
    let name: String
    let monthLabel: String
    let totalLabel: String
    let active: Bool
    let onSelect: () -> Void

    @State private var hovering = false

    private var bg: Color {
        if active { return Theme.accentTint14 }
        if hovering { return Theme.accentTint08 }
        return Color.clear
    }
    private var border: Color {
        active ? Theme.accentBorder45 : Theme.hairline
    }

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(name)
                    .font(Theme.ui(14, .semibold))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(monthLabel)
                    .font(Theme.mono(13))
                    .foregroundColor(Theme.accent)
                    .fixedSize()
                Text(totalLabel)
                    .font(Theme.mono(11.5))
                    .foregroundColor(Theme.faint)
                    .fixedSize()
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(bg)
            .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.controlRadius)
                    .stroke(border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Compact month picker styled like an inset input.
struct MonthPicker: View {
    @Binding var selection: String
    let options: [String]

    var body: some View {
        Menu {
            ForEach(options, id: \.self) { key in
                Button(DateHelp.monthLabel(fromKey: key)) { selection = key }
            }
        } label: {
            HStack(spacing: 6) {
                Text(DateHelp.monthLabel(fromKey: selection))
                    .font(Theme.ui(13))
                    .foregroundColor(Theme.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(Theme.muted)
            }
            .padding(.vertical, 7)
            .padding(.horizontal, 10)
            .background(Theme.inset)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Theme.inputBorder, lineWidth: 1)
            )
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
    }
}

/// Two-option segmented control for the recap view: Totals / By day.
struct RecapModeToggle: View {
    @Binding var byDay: Bool

    var body: some View {
        HStack(spacing: 6) {
            segment("Totals", active: !byDay) { byDay = false }
            segment("By day", active: byDay) { byDay = true }
        }
    }

    @ViewBuilder
    private func segment(_ title: String, active: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.ui(12.5, .semibold))
                .foregroundColor(active ? Theme.accent : Theme.muted)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(active ? Theme.accentTint14 : Theme.inset)
                .clipShape(RoundedRectangle(cornerRadius: 7))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .stroke(active ? Theme.accentBorder45 : Theme.inputBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

/// Primary "Copy recap" button — flexes to fill; turns green when copied.
struct CopyButton: View {
    let copied: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(copied ? "Copied!" : "Copy recap")
                .font(Theme.ui(14, .bold))
                .foregroundColor(Theme.onAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background((copied ? Theme.success : Theme.accent).brightness(hovering ? 0.06 : 0))
                .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}

/// Ghost button (Export .txt / Draft email) — accent text/border on hover;
/// dimmed and non-interactive when disabled.
struct GhostButton: View {
    let title: String
    var disabled: Bool = false
    let action: () -> Void
    @State private var hovering = false

    private var fg: Color {
        if disabled { return Theme.faint }
        return hovering ? Theme.accent : Theme.textSecondary
    }
    private var border: Color {
        (hovering && !disabled) ? Theme.accent : Theme.inputBorder
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(Theme.ui(14, .semibold))
                .foregroundColor(fg)
                .padding(.vertical, 10)
                .padding(.horizontal, 16)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.controlRadius)
                        .stroke(border, lineWidth: 1)
                )
                .opacity(disabled ? 0.5 : 1)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .onHover { if !disabled { hovering = $0 } }
    }
}
