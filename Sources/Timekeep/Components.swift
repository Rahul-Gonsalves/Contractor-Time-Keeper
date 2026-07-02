import SwiftUI

/// Card container: bg #161D27, 1px border #232D3B, radius 14, padding 20. No shadow.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 0) { content }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
    }
}

/// Uppercase section label: 12px / 600 / 0.08em tracking / muted.
struct SectionLabel: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(Theme.ui(12, .semibold))
            .tracking(0.96) // ~0.08em at 12px
            .foregroundColor(Theme.muted)
    }
}

/// Styled inset text field matching the input spec, with custom placeholder color
/// and an accent focus ring. Submits on Return.
struct InsetField: View {
    let placeholder: String
    @Binding var text: String
    var fontSize: CGFloat = 15
    var radius: CGFloat = Theme.controlRadius
    var vPad: CGFloat = 11
    var hPad: CGFloat = 13
    var onSubmit: (() -> Void)? = nil

    @FocusState private var focused: Bool

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(Theme.ui(fontSize))
                    .foregroundColor(Theme.placeholder)
            }
            TextField("", text: $text)
                .textFieldStyle(.plain)
                .font(Theme.ui(fontSize))
                .foregroundColor(Theme.textPrimary)
                .focused($focused)
                .onSubmit { onSubmit?() }
        }
        .padding(.vertical, vPad)
        .padding(.horizontal, hPad)
        .background(Theme.inset)
        .clipShape(RoundedRectangle(cornerRadius: radius))
        .overlay(
            RoundedRectangle(cornerRadius: radius)
                .stroke(focused ? Theme.accentBorder45 : Theme.inputBorder,
                        lineWidth: focused ? 2 : 1)
        )
    }
}

/// Compact date picker restricted to today-or-earlier, tinted to the accent so it
/// reads like the existing inputs. Used in the log form (secondary) and inline edit.
struct InsetDatePicker: View {
    @Binding var date: Date
    var body: some View {
        DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
            .labelsHidden()
            .datePickerStyle(.compact)
            .tint(Theme.accent)
            .font(Theme.ui(13))
            .fixedSize()
    }
}

/// A text button (Edit/Delete/etc.) that tints its foreground + background on hover.
struct HoverTextButton: View {
    let title: String
    var font: Font = Theme.ui(12.5)
    var baseColor: Color = Theme.faint
    var hoverColor: Color
    var hoverBg: Color
    var hPad: CGFloat = 6
    var vPad: CGFloat = 2
    var radius: CGFloat = 5
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(font)
                .foregroundColor(hovering ? hoverColor : baseColor)
                .padding(.horizontal, hPad)
                .padding(.vertical, vPad)
                .background(hovering ? hoverBg : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: radius))
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
    }
}
