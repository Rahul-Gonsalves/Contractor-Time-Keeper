import SwiftUI

/// App settings (⌘,). Currently a single optional default recap recipient,
/// persisted in UserDefaults and pre-filled into the "Draft email" To: field.
struct SettingsView: View {
    @AppStorage(SettingsKeys.recapRecipient) private var recapRecipient = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Recap email")
                .padding(.bottom, 2)

            Text("Send recaps to")
                .font(Theme.ui(13))
                .foregroundColor(Theme.textSecondary)

            InsetField(placeholder: "name@example.com (optional)", text: $recapRecipient)

            Text("Pre-filled into the To: field when you draft a recap email. Leave blank to fill it in yourself.")
                .font(Theme.ui(12))
                .foregroundColor(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(width: 360, alignment: .leading)
        .background(Theme.page)
        .preferredColorScheme(.dark)
    }
}

enum SettingsKeys {
    static let recapRecipient = "recapRecipient"
}
