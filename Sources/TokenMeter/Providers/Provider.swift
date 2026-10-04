import Foundation

/// A coding agent whose token usage can be read from logs it keeps on this machine.
protocol Provider: AnyObject {
    static var id: String { get }
    static var name: String { get }
    /// Shown in settings when parsing relies on an undocumented log format.
    static var experimental: Bool { get }
    /// True when the agent's data directory exists on this machine.
    static var isDetected: Bool { get }

    init()
    var totals: Totals { get }
    /// Reads whatever was written since the previous call.
    func scan()
}

extension Provider {
    static var experimental: Bool { false }
}

enum Providers {
    static let all: [any Provider.Type] = [
        ClaudeProvider.self,
        CodexProvider.self,
        GeminiProvider.self,
        GrokProvider.self,
    ]
}
