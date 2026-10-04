import Foundation

/// Codex CLI: ~/.codex/sessions/**/*.jsonl, `token_count` events carry the usage of the
/// last request plus a cumulative session total. Events repeat without new usage, so one
/// is counted only when the total moved. A forked or compacted session starts with the
/// parent's total and an empty last usage, so the parent is not counted twice.
/// The model comes from the preceding `turn_context` event.
final class CodexProvider: Provider {
    static let id = "codex"
    static let name = "Codex"
    static var isDetected: Bool { Files.exists(dir) }
    private static let dir = ".codex/sessions"

    private(set) var totals = Totals()
    private var tail = JSONLTail()
    private var lastTotal: [URL: Int] = [:]
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
              let total = info["total_token_usage"] as? [String: Any],
              let last = info["last_token_usage"] as? [String: Any]
        else { return }

        let totalTokens = Files.int(total["total_tokens"])
        guard lastTotal[file] != totalTokens else { return }
        lastTotal[file] = totalTokens

        // input_tokens includes cached reads and writes, output_tokens includes reasoning.
        let cacheRead = Files.int(last["cached_input_tokens"])
        let cacheWrite = Files.int(last["cache_write_input_tokens"])
        let usage = Usage(input: Files.int(last["input_tokens"]) - cacheRead - cacheWrite,
                          cacheRead: cacheRead, cacheWrite: cacheWrite,
                          output: Files.int(last["output_tokens"]))
        guard !usage.isEmpty else { return }

        totals.add(usage, model: model[file], day: Day.from(timestamp: json["timestamp"]))
    }
}
