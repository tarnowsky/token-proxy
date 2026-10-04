import Foundation

/// Codex CLI: ~/.codex/sessions/**/*.jsonl, `token_count` events carry a cumulative
/// `total_token_usage` per session; we count the delta between consecutive events.
/// The model comes from the preceding `turn_context` event.
final class CodexProvider: Provider {
    static let id = "codex"
    static let name = "Codex"
    static var isDetected: Bool { Files.exists(dir) }
    private static let dir = ".codex/sessions"

    private(set) var totals = Totals()
    private var tail = JSONLTail()
    private var lastTotal: [URL: Usage] = [:]
    private var model: [URL: String] = [:]

    func scan() {
        for file in Files.all(in: Self.dir, ext: "jsonl") {
            tail.readNewLines(file) { line($0, file: file) }
        }
    }

    private func line(_ line: Substring, file: URL) {
        if line.contains("\"turn_context\""), let json = Files.parse(Data(line.utf8)),
           json["type"] as? String == "turn_context",
           let name = (json["payload"] as? [String: Any])?["model"] as? String {
            model[file] = name
            return
        }

        guard line.contains("\"token_count\""),
              let json = Files.parse(Data(line.utf8)),
              let payload = json["payload"] as? [String: Any],
              payload["type"] as? String == "token_count",
              let info = payload["info"] as? [String: Any],
              let total = info["total_token_usage"] as? [String: Any]
        else { return }

        // input_tokens includes cached reads and writes, output_tokens includes reasoning.
        let cacheRead = Files.int(total["cached_input_tokens"])
        let cacheWrite = Files.int(total["cache_write_input_tokens"])
        let current = Usage(input: Files.int(total["input_tokens"]) - cacheRead - cacheWrite,
                            cacheRead: cacheRead, cacheWrite: cacheWrite,
                            output: Files.int(total["output_tokens"]))
        let previous = lastTotal[file] ?? Usage()
        lastTotal[file] = current

        var delta = current - previous
        if delta.hasNegative { delta = current } // counter reset
        guard !delta.isEmpty else { return }

        totals.add(delta, model: model[file], day: Day.from(timestamp: json["timestamp"]))
    }
}
