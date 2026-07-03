import SwiftUI

/// Focusable fields in the log form (used to move focus programmatically).
enum LogField: Hashable { case client, hours }

/// Pure client-autocomplete logic (unit-tested via --selftest).
enum Autocomplete {
    /// Client names that START WITH the query (case-insensitive), excluding an exact
    /// match, sorted alphabetically. Empty query → no matches (never "all clients").
    static func matches(query: String, names: [String]) -> [String] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return [] }
        return names
            .filter { let l = $0.lowercased(); return l.hasPrefix(q) && l != q }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// True when the query already equals an existing client name (case-insensitive).
    static func isExact(query: String, names: [String]) -> Bool {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return false }
        return names.contains { $0.compare(q, options: .caseInsensitive) == .orderedSame }
    }

    /// The dimmed completion shown after the caret: the remainder of `suggestion`
    /// after the typed prefix. Empty unless it's a proper (longer) prefix match.
    static func ghost(query: String, suggestion: String) -> String {
        guard suggestion.count > query.count,
              suggestion.lowercased().hasPrefix(query.lowercased()) else { return "" }
        return String(suggestion.dropFirst(query.count))
    }
}

/// Anchors the suggestions dropdown to the Client field's frame so it can be drawn
/// as an overlay of the whole form (on top of the rows below it).
struct ClientAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

extension View {
    /// Intercepts ↑/↓/Tab/Esc on the focused field when `enabled` (macOS 14+).
    /// `tab`/`escape` are only consumed when enabled, so normal behavior is preserved
    /// when the suggestion list is hidden.
    @ViewBuilder
    func onFieldKeys(enabled: Bool,
                     up: @escaping () -> Void,
                     down: @escaping () -> Void,
                     tab: @escaping () -> Void,
                     escape: @escaping () -> Void) -> some View {
        if #available(macOS 14.0, *) {
            self.onKeyPress { press in
                guard enabled else { return .ignored }
                let k = press.key
                if k == .upArrow   { up();     return .handled }
                if k == .downArrow { down();   return .handled }
                if k == .tab       { tab();    return .handled }
                if k == .escape    { escape(); return .handled }
                return .ignored
            }
        } else {
            self
        }
    }
}
