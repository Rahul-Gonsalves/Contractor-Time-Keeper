import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// Monthly recap card. Owns its own transient UI state (copied flash, hover, notice)
/// so hovering/copying here never re-renders the rest of the window.
struct RecapCardView: View {
    @ObservedObject var store: TimeStore
    @Binding var recapMonth: String
    @Binding var recapByDay: Bool

    @AppStorage(SettingsKeys.recapRecipient) private var recapRecipient = ""

    @State private var copied = false
    @State private var copyToken = 0
    @State private var recapNotice: String? = nil
    @State private var noticeToken = 0
    @State private var boxHovered = false
    @State private var iconHovered = false

    private var monthHasHours: Bool { store.monthTotal(recapMonth) > 0 }

    var body: some View {
        Card {
            HStack(spacing: 10) {
                SectionLabel(text: "Monthly recap")
                Spacer(minLength: 10)
                MonthPicker(selection: $recapMonth, options: store.monthOptions())
            }
            .padding(.bottom, 12)

            HStack(spacing: 6) {
                PillToggle(left: "Totals", right: "By day", isRight: $recapByDay)
                Spacer(minLength: 0)
            }
            .padding(.bottom, 12)

            ScrollView(.horizontal, showsIndicators: false) {
                Text(store.recap(monthKey: recapMonth, byDay: recapByDay))
                    .font(Theme.mono(12.5))
                    .foregroundColor(Color(hex: "CFD9E6"))
                    .lineSpacing(12.5 * 0.7)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(Theme.inset)
            .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius))
            .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius).stroke(Theme.hairline, lineWidth: 1))
            .overlay(alignment: .topTrailing) { copyIcon }
            .onHover { boxHovered = $0 }
            .animation(.easeInOut(duration: 0.12), value: boxHovered)
            .animation(.easeInOut(duration: 0.12), value: copied)
            .padding(.bottom, 12)

            HStack(spacing: 8) {
                GhostButton(title: "Export .xlsx", fill: true, action: exportXLSX)
                GhostButton(title: "Draft email", disabled: !monthHasHours, fill: true, action: draftEmail)
            }

            if let notice = recapNotice {
                Text(notice)
                    .font(Theme.ui(12.5))
                    .foregroundColor(Theme.muted)
                    .padding(.top, 10)
            }
        }
    }

    @ViewBuilder
    private var copyIcon: some View {
        if boxHovered || copied {
            Button(action: copyRecap) {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(copied ? Theme.success : (iconHovered ? Theme.accent : Theme.muted))
                    .frame(width: 28, height: 28)
                    .background(iconHovered && !copied ? Theme.accentTint12 : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .onHover { iconHovered = $0 }
            .help("Copy recap")
            .contextMenu {
                Button("Copy recap", action: copyRecap)
                Button("Copy formatted (for email)", action: copyFormatted)
            }
            .padding(10)
            .transition(.opacity)
        }
    }

    private func copyRecap() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(store.recap(monthKey: recapMonth, byDay: recapByDay), forType: .string)
        flashCopied()
    }

    private func copyFormatted() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(store.recapHTML(monthKey: recapMonth, byDay: recapByDay), forType: .html)
        pb.setString(store.recap(monthKey: recapMonth, byDay: recapByDay), forType: .string)
        flashCopied()
    }

    private func flashCopied() {
        copied = true
        copyToken += 1
        let token = copyToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
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

    private func draftEmail() {
        let subject = store.recapSubject(monthKey: recapMonth)
        let to = recapRecipient.trimmingCharacters(in: .whitespacesAndNewlines)
        let html = store.recapEmailHTML(monthKey: recapMonth, byDay: recapByDay)
        if let attr = attributedString(fromHTML: html),
           let service = NSSharingService(named: .composeEmail),
           service.canPerform(withItems: [attr]) {
            service.subject = subject
            if !to.isEmpty { service.recipients = [to] }
            service.perform(withItems: [attr])
            return
        }
        let body = store.recapEmailBody(monthKey: recapMonth, byDay: recapByDay)
        guard let url = MailDraft.mailtoURL(subject: subject, body: body, to: to) else { return }
        let ws = NSWorkspace.shared
        if let outlook = ws.urlForApplication(withBundleIdentifier: "com.microsoft.Outlook") {
            let config = NSWorkspace.OpenConfiguration()
            ws.open([url], withApplicationAt: outlook, configuration: config) { _, error in
                if error != nil { DispatchQueue.main.async { openDefaultOrCopy(url, body: body) } }
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
