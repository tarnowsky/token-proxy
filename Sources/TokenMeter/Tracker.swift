import Foundation

/// Owns the connected providers. "Connecting" only enables reading that agent's local logs;
/// the choice is remembered across launches.
final class Tracker: ObservableObject {
    private static let defaultsKey = "connectedProviders"

    @Published private(set) var connected: [String]
    private var instances: [String: any Provider] = [:]

    init() {
        connected = UserDefaults.standard.stringArray(forKey: Self.defaultsKey) ?? []
        connected.forEach(start)
    }

    func isConnected(_ type: any Provider.Type) -> Bool { connected.contains(type.id) }

    func connect(_ type: any Provider.Type) {
        guard !isConnected(type) else { return }
        connected.append(type.id)
        start(type.id)
        save()
    }

    func disconnect(_ type: any Provider.Type) {
        connected.removeAll { $0 == type.id }
        instances[type.id] = nil
        save()
    }

    func scan() { instances.values.forEach { $0.scan() } }

    /// Connected providers in the canonical order, with their totals.
    var active: [(type: any Provider.Type, totals: Totals)] {
        Providers.all.compactMap { type in instances[type.id].map { (type, $0.totals) } }
    }

    /// Detected on this machine but not connected yet.
    var suggested: [any Provider.Type] {
        Providers.all.filter { $0.isDetected && !isConnected($0) }
    }

    private func start(_ id: String) {
        guard let type = Providers.all.first(where: { $0.id == id }) else { return }
        let provider = type.init()
        provider.scan()
        instances[id] = provider
    }

    private func save() {
        UserDefaults.standard.set(connected, forKey: Self.defaultsKey)
    }
}
