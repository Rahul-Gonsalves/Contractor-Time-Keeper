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
    var height: CGFloat? = nil   // when set, fixes the control height
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
        .frame(height: height)   // nil → natural height
        .background(Theme.inset)
        .clipShape(RoundedRectangle(cornerRadius: radius))
        .overlay(
            RoundedRectangle(cornerRadius: radius)
                .stroke(focused ? Theme.accentBorder45 : Theme.inputBorder,
                        lineWidth: focused ? 2 : 1)
        )
    }
}

/// A date field styled exactly like `InsetField` (same bg/border/radius) with a
/// calendar glyph. Tapping it opens a graphical calendar popover restricted to
/// today-or-earlier. Used in the log form and inline edit.
struct DateFieldBox: View {
    @Binding var date: Date
    var fontSize: CGFloat = 15
    var radius: CGFloat = Theme.controlRadius
    var vPad: CGFloat = 11
    var hPad: CGFloat = 13
    var height: CGFloat? = nil    // when set, fixes the control height
    var fillWidth: Bool = false   // when true, the box fills the width it's given

    @State private var showing = false

    var body: some View {
        Button { showing.toggle() } label: {
            HStack(spacing: 8) {
                Text(DateHelp.fieldLabel(date))
                    .font(Theme.ui(fontSize))
                    .foregroundColor(Theme.textPrimary)
                Image(systemName: "calendar")
                    .font(.system(size: fontSize - 2))
                    .foregroundColor(Theme.muted)
            }
            .padding(.vertical, vPad)
            .padding(.horizontal, hPad)
            .frame(maxWidth: fillWidth ? .infinity : nil, alignment: .leading)
            .frame(height: height)   // nil → natural height
            .background(Theme.inset)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(showing ? Theme.accentBorder45 : Theme.inputBorder,
                            lineWidth: showing ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showing, arrowEdge: .bottom) {
            DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .tint(Theme.accent)
                .padding(12)
                .frame(width: 260)
                .background(Theme.card)
                .preferredColorScheme(.dark)
        }
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
