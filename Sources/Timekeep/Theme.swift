import SwiftUI

/// Design tokens from the handoff spec. The flat dark palette is the source of truth.
enum Theme {
    // Backgrounds
    static let page          = Color(hex: "0E131A")
    static let card          = Color(hex: "161D27")
    static let cardBorder    = Color(hex: "232D3B")
    static let inset         = Color(hex: "0F1620") // input / preview background
    static let inputBorder   = Color(hex: "26313F")
    static let hairline      = Color(hex: "1D2632")
    static let rowSeparator  = Color(hex: "171F2A")

    // Text
    static let textPrimary   = Color(hex: "E6ECF4")
    static let textSecondary = Color(hex: "AEB9C9")
    static let muted         = Color(hex: "8C9AAC")
    static let faint         = Color(hex: "5C6B7E")
    static let placeholder   = Color(hex: "55647A")

    // Accent + status
    static let accent        = Color(hex: "7DA7F2")
    static let accentHover   = Color(hex: "93B7F7")
    static let onAccent      = Color(hex: "0D1420")
    static let success       = Color(hex: "69D29A")
    static let danger        = Color(hex: "F28B8B")

    // Accent tints
    static let accentTint08  = Color(hex: "7DA7F2", alpha: 0.08)
    static let accentTint10  = Color(hex: "7DA7F2", alpha: 0.10)
    static let accentTint12  = Color(hex: "7DA7F2", alpha: 0.12)
    static let accentTint14  = Color(hex: "7DA7F2", alpha: 0.14)
    static let accentBorder30 = Color(hex: "7DA7F2", alpha: 0.30)
    static let accentBorder45 = Color(hex: "7DA7F2", alpha: 0.45)
    static let dangerTint10  = Color(hex: "F28B8B", alpha: 0.10)

    // Radii
    static let cardRadius: CGFloat   = 14
    static let controlRadius: CGFloat = 9
    static let editRadius: CGFloat   = 7
    static let pillRadius: CGFloat   = 999

    // Fonts — SF Pro (UI) + SF Mono (numbers/recap), preserving the size/weight hierarchy.
    static func ui(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight)
    }
    static func mono(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension Color {
    init(hex: String, alpha: Double = 1.0) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255.0
        let g = Double((v >> 8) & 0xFF) / 255.0
        let b = Double(v & 0xFF) / 255.0
        self = Color(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
