import Foundation

/// Codex CLI: ~/.codex/sessions/**/*.jsonl, `token_count` events carry a cumulative
/// `total_token_usage` per session; we count the delta between consecutive events.
final class CodexProvider: Provider {
    static let id = "codex"
    static let name = "Codex"
    static var isDetected: Bool { Files.exists(dir) }
    private static let dir = ".codex/sessions"

    private(set) var totals = Totals()
    private var tail = JSONLTail()
    private var lastTotal: [URL: Usage] = [:]

    func scan() {
        for file in Files.all(in: Self.dir, ext: "jsonl") {
            tail.readNewLines(file) { line($0, file: file) }
        }
    }

    private func line(_ line: Substring, file: URL) {
        guard line.contains("\"token_count\""),
              let json = Files.parse(Data(line.utf8)),
              let payload = json["payload"] as? [String: Any],
              payload["type"] as? String == "token_count",
              let info = payload["info"] as? [String: Any],
              let total = info["total_token_usage"] as? [String: Any]
        else { return }

        // input_tokens already includes cached input, output_tokens includes reasoning.
        let current = Usage(input: Files.int(total["input_tokens"]), output: Files.int(total["output_tokens"]))
        let previous = lastTotal[file] ?? Usage()
        lastTotal[file] = current

        var delta = Usage(input: current.input - previous.input, output: current.output - previous.output)
        if delta.input < 0 || delta.output < 0 { delta = current } // counter reset
        guard !delta.isEmpty else { return }

        totals.add(delta, day: Day.from(timestamp: json["timestamp"]))
    }
}
