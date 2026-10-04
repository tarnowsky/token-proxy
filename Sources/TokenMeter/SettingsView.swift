import SwiftUI

struct SettingsView: View {
    @ObservedObject var tracker: Tracker

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Providerzy").font(.headline)
            ForEach(Providers.all.indices, id: \.self) { i in
                row(Providers.all[i])
                if i < Providers.all.count - 1 { Divider() }
            }
            Text("Połączenie oznacza tylko czytanie lokalnych logów danego narzędzia. Nic nie jest wysyłane.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Divider()
            Picker("Na pasku menu (dziś)", selection: $tracker.barDisplay) {
                ForEach(BarDisplay.allCases, id: \.self) { Text($0.label) }
            }
            .pickerStyle(.segmented)
            Text("Koszt to szacunek wg cennika API (LiteLLM). Przy subskrypcji to wartość zużycia, nie rachunek.")
                .font(.caption)
                .foregroundStyle(.secondary)
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
                        Text("eksperymentalne")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .background(.orange.opacity(0.2), in: Capsule())
                    }
                }
                Text(type.isDetected ? "Wykryto na tym komputerze" : "Nie wykryto")
                    .font(.caption)
                    .foregroundStyle(type.isDetected ? .green : .secondary)
            }
            Spacer()
            if tracker.isConnected(type) {
                Button("Rozłącz") { tracker.disconnect(type) }
            } else {
                Button("Połącz") { tracker.connect(type) }.buttonStyle(.borderedProminent)
            }
        }
    }
}
