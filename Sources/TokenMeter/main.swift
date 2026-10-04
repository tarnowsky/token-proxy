import AppKit
import Combine
import SwiftUI

let appVersion = "1.0.0-beta.1"

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let tracker = Tracker()
    private var timer: Timer?
    private var settingsWindow: NSWindow?
    private var subscriptions = Set<AnyCancellable>()
    private let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.font = font
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        refresh()
        tracker.$barDisplay.dropFirst().sink { [weak self] _ in
            DispatchQueue.main.async { self?.refresh() }
        }.store(in: &subscriptions)
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
    }

    private func refresh() {
        Pricing.shared.refreshIfStale { [weak self] in
            self?.tracker.reload()
            self?.refresh()
        }
        tracker.scan()
        let active = tracker.active
        if active.isEmpty {
            statusItem.button?.title = "Tokeny"
            statusItem.button?.toolTip = "Połącz się z narzędziem, żeby liczyć tokeny"
        } else {
            let today = active.map(\.totals.today).reduce(Usage(), +)
            let tokens = "↑\(fmt(today.totalInput)) ↓\(fmt(today.output))"
            let cost = "≈\(fmtCost(today.cost))"
            statusItem.button?.title = switch tracker.barDisplay {
            case .tokens: tokens
            case .cost: cost
            case .both: "\(tokens) \(cost)"
            }
            statusItem.button?.toolTip = "Dziś: tokeny wejście ↑ / wyjście ↓, ≈ koszt wg cennika API"
        }
    }

    // Rebuilt on every open so it reflects the latest totals and connections.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let active = tracker.active

        if !active.isEmpty {
            section(menu, "Dziś", active.map { ($0.type.name, $0.totals.today) })
            menu.addItem(.separator())
            section(menu, "Od początku", active.map { ($0.type.name, $0.totals.allTime) })
            note(menu, "≈ koszt wg cennika API, nie rachunek z subskrypcji")
            let unpriced = Set(active.flatMap(\.totals.unpriced)).sorted()
            if !unpriced.isEmpty { note(menu, "Bez ceny: " + unpriced.joined(separator: ", ")) }
            menu.addItem(.separator())
        }

        for type in tracker.suggested {
            let item = NSMenuItem(title: "Połącz z \(type.name)", action: #selector(connect(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = type.id
            menu.addItem(item)
        }
        if active.isEmpty && tracker.suggested.isEmpty {
            let item = NSMenuItem(title: "Nie wykryto żadnego narzędzia", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
        }
        if !tracker.suggested.isEmpty || active.isEmpty { menu.addItem(.separator()) }

        if !active.isEmpty {
            let settings = NSMenuItem(title: "Ustawienia…", action: #selector(openSettings), keyEquivalent: ",")
            settings.target = self
            menu.addItem(settings)
        }
        menu.addItem(NSMenuItem(title: "Zakończ", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    @objc private func connect(_ sender: NSMenuItem) {
        guard let type = Providers.all.first(where: { $0.id == sender.representedObject as? String }) else { return }
        tracker.connect(type)
        refresh()
    }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(tracker: tracker)))
            window.title = "TokenMeter: ustawienia"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            settingsWindow = window
        }
        settingsWindow?.center()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func section(_ menu: NSMenu, _ title: String, _ rows: [(String, Usage)]) {
        let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        let width = rows.map(\.0.count).max() ?? 0
        for (name, usage) in rows {
            menu.addItem(row(name, usage, width: width))
        }
        if rows.count > 1 {
            menu.addItem(row("Łącznie", rows.map(\.1).reduce(Usage(), +), width: width))
        }
    }

    private func row(_ label: String, _ u: Usage, width: Int) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let name = label.padding(toLength: max(width, 7), withPad: " ", startingAt: 0)
        let text = "\(name)  ↑ \(pad(fmt(u.totalInput)))  ↓ \(pad(fmt(u.output)))  ≈ \(fmtCost(u.cost))"
        item.attributedTitle = NSAttributedString(string: text, attributes: [.font: font])
        return item
    }

    private func note(_ menu: NSMenu, _ text: String) {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        item.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
            .foregroundColor: NSColor.secondaryLabelColor,
        ])
        item.isEnabled = false
        menu.addItem(item)
    }

    private func pad(_ s: String) -> String {
        String(repeating: " ", count: max(0, 6 - s.count)) + s
    }

    private func fmtCost(_ usd: Double) -> String {
        switch usd {
        case 1000...: String(format: "$%.0f", usd)
        case 0.01...: String(format: "$%.2f", usd)
        case 0: "$0"
        default: "<$0.01"
        }
    }

    private func fmt(_ n: Int) -> String {
        switch n {
        case 1_000_000_000...: String(format: "%.2fB", Double(n) / 1e9)
        case 1_000_000...: String(format: "%.1fM", Double(n) / 1e6)
        case 1_000...: String(format: "%.1fk", Double(n) / 1e3)
        default: "\(n)"
        }
    }
}

if CommandLine.arguments.contains("--version") {
    print("TokenMeter \(appVersion)")
    exit(0)
}

if CommandLine.arguments.contains("--print") {
    if !Pricing.shared.isLoaded {
        var done = false
        Pricing.shared.refreshIfStale { done = true }
        let deadline = Date().addingTimeInterval(15)
        while !done && Date() < deadline { RunLoop.main.run(until: Date().addingTimeInterval(0.1)) }
    }
    for type in Providers.all {
        let provider = type.init()
        provider.scan()
        print("\(type.name) (wykryto: \(type.isDetected), bez ceny: \(provider.totals.unpriced.sorted()))")
        for (day, u) in provider.totals.days.sorted(by: { $0.key < $1.key }) {
            print("  \(day) $\(String(format: "%.2f", u.cost)) in \(u.totalInput) (cache read \(u.cacheRead), write \(u.cacheWrite + u.cacheWrite1h)) out \(u.output)")
        }
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
