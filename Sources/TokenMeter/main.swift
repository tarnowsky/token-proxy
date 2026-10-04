import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let scanner = LogScanner()
    private var timer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
    }

    private func refresh() {
        scanner.scan()
        let totals = scanner.totals
        let today = Source.allCases.map(totals.today).reduce(Usage(), +)
        statusItem.button?.title = "↑\(fmt(today.input)) ↓\(fmt(today.output))"
        statusItem.button?.toolTip = "Tokeny dziś: wejście ↑ / wyjście ↓"
        statusItem.menu = buildMenu(totals)
    }

    private func buildMenu(_ totals: Totals) -> NSMenu {
        let menu = NSMenu()
        section(menu, "Dziś", totals.today)
        menu.addItem(.separator())
        section(menu, "Od początku", totals.allTime)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Zakończ", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    private func section(_ menu: NSMenu, _ title: String, _ usage: (Source) -> Usage) {
        let header = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)
        for source in Source.allCases {
            menu.addItem(row(source.rawValue, usage(source)))
        }
        menu.addItem(row("Łącznie", Source.allCases.map(usage).reduce(Usage(), +)))
    }

    private func row(_ label: String, _ u: Usage) -> NSMenuItem {
        let item = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        let text = "\(label.padding(toLength: 8, withPad: " ", startingAt: 0))  ↑ \(fmt(u.input))   ↓ \(fmt(u.output))"
        item.attributedTitle = NSAttributedString(string: text, attributes: [.font: font])
        return item
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

if CommandLine.arguments.contains("--print") {
    let scanner = LogScanner()
    scanner.scan()
    for (source, days) in scanner.totals.days {
        for (day, u) in days.sorted(by: { $0.key < $1.key }) {
            print(source.rawValue, day, "in", u.input, "out", u.output)
        }
    }
    exit(0)
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
