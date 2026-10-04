import SwiftUI

struct SettingsView: View {
    @ObservedObject var tracker: Tracker

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(tr("Providerzy", "Providers")).font(.headline)
            ForEach(Providers.all.indices, id: \.self) { i in
                row(Providers.all[i])
                if i < Providers.all.count - 1 { Divider() }
            }
            Text(tr("Połączenie oznacza tylko czytanie lokalnych logów danego narzędzia. Nic nie jest wysyłane.",
                    "Connecting only reads the tool's local logs. Nothing is sent anywhere."))
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
            Picker(tr("Na pasku menu (dziś)", "Menu bar (today)"), selection: $tracker.barDisplay) {
                ForEach(BarDisplay.allCases, id: \.self) { Text($0.label) }
            }
            .pickerStyle(.segmented)
            Text(tr("Koszt to szacunek wg cennika API (LiteLLM). Przy subskrypcji to wartość zużycia, nie rachunek.",
                    "Cost is an estimate at API prices (LiteLLM). With a subscription it is the value of your usage, not your bill."))
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker(tr("Język", "Language"), selection: $tracker.language) {
                ForEach(Language.allCases, id: \.self) { Text($0.label) }
            }
            Text("TokenMeter \(appVersion)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(20)
        .frame(width: 380)
    }

    private func row(_ type: any Provider.Type) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(type.name)
                    if type.experimental {
                        Text(tr("eksperymentalne", "experimental"))
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .background(.orange.opacity(0.2), in: Capsule())
                    }
                }
                Text(type.isDetected ? tr("Wykryto na tym komputerze", "Detected on this Mac") : tr("Nie wykryto", "Not detected"))
                    .font(.caption)
                    .foregroundStyle(type.isDetected ? .green : .secondary)
            }
            Spacer()
            if tracker.isConnected(type) {
                Button(tr("Rozłącz", "Disconnect")) { tracker.disconnect(type) }
            } else {
                Button(tr("Połącz", "Connect")) { tracker.connect(type) }.buttonStyle(.borderedProminent)
            }
        }
    }
}
