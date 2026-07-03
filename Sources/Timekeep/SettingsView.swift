import SwiftUI

/// App settings (⌘,). Currently a single optional default recap recipient,
/// persisted in UserDefaults and pre-filled into the "Draft email" To: field.
struct SettingsView: View {
    @AppStorage(SettingsKeys.recapRecipient) private var recapRecipient = ""
    @AppStorage(SettingsKeys.hourlyRate) private var hourlyRate = 20.0
    @State private var rateText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Rate")
                .padding(.bottom, 2)

            Text("Hourly rate")
                .font(Theme.ui(13))
                .foregroundColor(Theme.textSecondary)

            HStack(spacing: 6) {
                Text("$").font(Theme.ui(15)).foregroundColor(Theme.muted)
                InsetField(placeholder: "20", text: $rateText)
                Text("/hr").font(Theme.ui(13)).foregroundColor(Theme.muted)
            }
            .onAppear { rateText = trimNumber(hourlyRate) }
            .onChange(of: rateText) { _ in
                let cleaned = rateText.replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
                if let v = Double(cleaned), v >= 0 { hourlyRate = (v * 100).rounded() / 100 }
            }

            SectionLabel(text: "Recap email")
                .padding(.top, 8)
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

    private func trimNumber(_ v: Double) -> String {
        v == v.rounded() ? String(Int(v)) : String(v)
    }
}

enum SettingsKeys {
    static let recapRecipient = "recapRecipient"
    static let hourlyRate = "hourlyRate"
}
